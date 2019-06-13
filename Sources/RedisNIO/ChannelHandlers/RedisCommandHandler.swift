//===----------------------------------------------------------------------===//
//
// This source file is part of the RedisNIO open source project
//
// Copyright (c) 2019 RedisNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RedisNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct Foundation.UUID
import Logging
import NIO

/// A context for `RedisCommandHandler` to operate within.
public struct RedisCommandContext {
    /// A full command keyword and arguments stored as a single `RESPValue`.
    public let command: RESPValue
    /// A promise expected to be fulfilled with the `RESPValue` response to the command from Redis.
    public let responsePromise: EventLoopPromise<RESPValue>

    public init(command: RESPValue, promise: EventLoopPromise<RESPValue>) {
        self.command = command
        self.responsePromise = promise
    }
}

/// A `ChannelDuplexHandler` that works with `RedisCommandContext`s to send commands and forward responses.
public final class RedisCommandHandler {
    /// Queue of promises waiting to receive a response value from a sent command.
    private var commandResponseQueue: CircularBuffer<EventLoopPromise<RESPValue>>
    private var logger: Logger

    deinit {
        guard commandResponseQueue.count > 0 else { return }
        logger.warning("Command handler deinit when queue is not empty. Current size: \(commandResponseQueue.count)")
    }

    public init(logger: Logger = Logger(label: "RedisNIO.CommandHandler"), initialQueueCapacity: Int = 5) {
        self.commandResponseQueue = CircularBuffer(initialCapacity: initialQueueCapacity)
        self.logger = logger
        self.logger[metadataKey: "CommandHandler"] = "\(UUID())"
    }
}

// MARK: ChannelInboundHandler

extension RedisCommandHandler: ChannelInboundHandler {
    /// See `ChannelInboundHandler.InboundIn`
    public typealias InboundIn = RESPValue

    /// Invoked by NIO when an error has been thrown. The command response promise at the front of the queue will be
    /// failed with the error.
    ///
    /// See `ChannelInboundHandler.errorCaught(context:error:)`
    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        let queue = self.commandResponseQueue
        
        assert(queue.count > 0, "Received unexpected error while idle: \(error.localizedDescription)")
        
        self.commandResponseQueue.removeAll()
        queue.forEach { $0.fail(error) }
        
        logger.critical("Error in channel pipeline.", metadata: ["error": .string(error.localizedDescription)])
        
        context.fireErrorCaught(error)
    }

    /// Invoked by NIO when a read has been fired from earlier in the response chain. This forwards the unwrapped
    /// `RESPValue` to the promise awaiting a response at the front of the queue.
    ///
    /// See `ChannelInboundHandler.channelRead(context:data:)`
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let value = self.unwrapInboundIn(data)

        guard let leadPromise = self.commandResponseQueue.popFirst() else {
            assertionFailure("Read triggered with an empty promise queue! Ignoring: \(value)")
            logger.critical("Read triggered with no promise waiting in the queue!")
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
    /// See `ChannelOutboundHandler.OutboundIn`
    public typealias OutboundIn = RedisCommandContext
    /// See `ChannelOutboundHandler.OutboundOut`
    public typealias OutboundOut = RESPValue

    /// Invoked by NIO when a `write` has been requested on the `Channel`.
    /// This unwraps a `RedisCommandContext`, retaining a callback to forward a response to later, and forwards
    /// the underlying command data further into the pipeline.
    ///
    /// See `ChannelOutboundHandler.write(context:data:promise:)`
    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let commandContext = self.unwrapOutboundIn(data)
        self.commandResponseQueue.append(commandContext.responsePromise)
        context.write(
            self.wrapOutboundOut(commandContext.command),
            promise: promise
        )
    }
}
