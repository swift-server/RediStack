//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2019 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct Foundation.UUID
import Logging
import NIO

/// The `NIO.ChannelOutboundHandler.OutboundIn` type for `RedisCommandHandler`.
///
/// This holds the full command message to be sent to Redis, and an `NIO.EventLoopPromise` to be fulfilled when a response has been received.
/// - Important: This struct has _reference semantics_ due to the retention of the `NIO.EventLoopPromise`.
public struct RedisCommand {
    /// The command keyword that will be sent to Redis.
    public let keyword: String
    /// The arguments to be sent as the command.
    public let arguments: [RESPValue]
    /// A promise to be fulfilled with the sent message's response from Redis.
    public let responsePromise: EventLoopPromise<RESPValue>

    public init(keyword: String, arguments: [RESPValue], responsePromise promise: EventLoopPromise<RESPValue>) {
        self.keyword = keyword
        self.arguments = arguments
        self.responsePromise = promise
    }
    
    /// Serializes the `RedisCommand` into a `RESPValue` formatted message ready to be sent to Redis.
    ///
    /// The format is (command, [arguments...]) stored as a single `RESPValue.array` value.
    /// - Returns: The command keyword and arguments represented as a single `RESPValue`.
    public func serialized() -> RESPValue {
        var elements = [self.keyword.convertedToRESPValue()]
        elements.append(contentsOf: self.arguments)
        return .array(elements)
    }
}

/// An object that operates in a First In, First Out (FIFO) request-response cycle.
///
/// `RedisCommandHandler` is a `NIO.ChannelDuplexHandler` that sends `RedisCommand` instances to Redis,
/// and fulfills the command's `NIO.EventLoopPromise` as soon as a `RESPValue` response has been received from Redis.
public final class RedisCommandHandler {
    public enum State {
        case `default`
        case pubsub(callbackMap: [String: [RedisPubSubMessageCallback]])
        case error(Error)
    }
    
    private var state: State = .default
    
    /// FIFO queue of promises waiting to receive a response value from a sent command.
    private var commandResponseQueue: CircularBuffer<EventLoopPromise<RESPValue>>
    private var logger: Logger

    deinit {
        guard self.commandResponseQueue.count > 0 else { return }
        self.logger[metadataKey: "Queue Size"] = "\(self.commandResponseQueue.count)"
        self.logger.warning("Command handler deinit when queue is not empty")
    }

    /// - Parameters:
    ///     - initialQueueCapacity: The initial queue size to start with. The default is `3`. `RedisCommandHandler` stores all
    ///         `RedisCommand.responsePromise` objects into a buffer, and unless you intend to execute several concurrent commands against Redis,
    ///         and don't want the buffer to resize, you shouldn't need to set this parameter.
    ///     - logger: The `Logging.Logger` instance to use.
    ///         The logger will have a `Foundation.UUID` value attached as metadata to uniquely identify this instance.
    public init(initialQueueCapacity: Int = 3, logger: Logger = Logger(label: "RediStack.CommandHandler")) {
        self.commandResponseQueue = CircularBuffer(initialCapacity: initialQueueCapacity)
        self.logger = logger
        self.logger[metadataKey: "CommandHandler"] = "\(UUID())"
    }
}

// MARK: ChannelInboundHandler

extension RedisCommandHandler: ChannelInboundHandler {
    /// See `NIO.ChannelInboundHandler.InboundIn`
    public typealias InboundIn = RESPValue

    /// Invoked by SwiftNIO when an error has been thrown. The command queue will be drained, with each promise in the queue being failed with the error thrown.
    ///
    /// See `NIO.ChannelInboundHandler.errorCaught(context:error:)`
    /// - Important: This will also close the socket connection to Redis.
    /// - Note:`RedisMetrics.commandFailureCount` is **not** incremented from this error.
    ///
    /// A `Logging.LogLevel.critical` message will be written with the caught error.
    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        self.state = .error(error)
        
        let queue = self.commandResponseQueue
        
        self.commandResponseQueue.removeAll()
        queue.forEach { $0.fail(error) }
        
        self.logger.critical("Error in channel pipeline.", metadata: ["error": "\(error.localizedDescription)"])
        
        context.close(promise: nil)
    }

    /// Invoked by SwiftNIO when a read has been fired from earlier in the response chain.
    /// This forwards the decoded `RESPValue` response message to the promise waiting to be fulfilled at the front of the command queue.
    /// - Note: `RedisMetrics.commandFailureCount` and `RedisMetrics.commandSuccessCount` are incremented from this method.
    ///
    /// See `NIO.ChannelInboundHandler.channelRead(context:data:)`
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let value = self.unwrapInboundIn(data)
        
        // check if it's a PubSub message, handling it if it is - otherwise treating it as a normal response

        guard let leadPromise = self.commandResponseQueue.popFirst() else {
            self.logger.critical("Read triggered with no promise waiting in the queue!")
            return
        }

        switch value {
        case .error(let e):
            leadPromise.fail(e)
            RedisMetrics.commandFailureCount.increment()

        default:
            leadPromise.succeed(value)
            RedisMetrics.commandSuccessCount.increment()
        }
    }
}

// MARK: ChannelOutboundHandler

extension RedisCommandHandler: ChannelOutboundHandler {
    /// See `NIO.ChannelOutboundHandler.OutboundIn`
    public typealias OutboundIn = RedisCommand
    /// See `NIO.ChannelOutboundHandler.OutboundOut`
    public typealias OutboundOut = RESPValue

    /// Invoked by SwiftNIO when a `write` has been requested on the `Channel`.
    /// This unwraps a `RedisCommand`, storing the `NIO.EventLoopPromise` in a command queue,
    /// to fulfill later with the response to the command that is about to be sent through the `NIO.Channel`.
    ///
    /// See `NIO.ChannelOutboundHandler.write(context:data:promise:)`
    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let command = self.unwrapOutboundIn(data)
        
        switch self.state {
        case .pubsub:
            switch command.keyword.lowercased() {
            case "subscribe", "psubscribe",
                 "unsubscribe", "punsubscribe",
                 "ping", "quit":
                fallthrough
            default: promise?.fail(RedisClientError.illegalPubSubCommand(command.keyword))
            }
            break
        case .default:
            self.commandResponseQueue.append(command.responsePromise)
            context.write(
                self.wrapOutboundOut(command.serialized()),
                promise: promise
            )
        case let .error(e): promise?.fail(e)
        }
    }
}

// MARK: PubSub

/// A subscription callback handler for PubSub messages.
/// - Parameters:
///     - channel: The PubSub channel name that published the message.
///     - message: The published message's data.
public typealias RedisPubSubMessageCallback = (_ channel: String, _ message: RESPValue) -> Void

extension RedisCommandHandler {
//    private func handlePubSubMessage(_ message: RESPValue, from channel: String, type: PubSubMessageType) -> Int? {
////        switch type {
////            // we're just changing subscriptions, so update our subscription count
////        }
//    }
    
    private enum PubSubMessageType {
        case subscriptionChange
        case message
        
        init?(fromRESPValue value: RESPValue) {
            switch value.string {
            case "subscribe", "psubscribe", "unsubscribe", "punsubscribe": self = .subscriptionChange
            case "message", "pmessage": self = .message
            default: return nil
            }
        }
    }
}
