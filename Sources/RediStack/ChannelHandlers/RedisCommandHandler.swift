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

import NIO

/// An object that operates in a First In, First Out (FIFO) request-response cycle.
///
/// `RedisCommandHandler` is a `NIO.ChannelDuplexHandler` that sends `RedisCommand` instances to Redis,
/// and fulfills the command's `NIO.EventLoopPromise` as soon as a `RESPValue` response has been received from Redis.
public final class RedisCommandHandler {
    public typealias ResponsePromise = EventLoopPromise<RESPValue>

    /// FIFO queue of promises waiting to receive a response value from a sent command.
    private var responseQueue: CircularBuffer<ResponsePromise>

    deinit {
        if !self.responseQueue.isEmpty {
            assertionFailure("Command handler deinit when queue is not empty! Queue size: \(self.responseQueue.count)")
        }
    }

    /// Creates a new request-response loop handler for Redis commands.
    ///
    /// Unless you intend to execute several concurrent commands using the same connection **and** don't want the internal buffer of pending responses to
    /// resize, you should not need to provide an `initialQueueCapacity` value.
    /// - Parameter initialQueueCapacity: The initial size of the internal buffer of pending responses. The default is `3`.
    public init(initialQueueCapacity: Int = 3) {
        self.responseQueue = CircularBuffer(initialCapacity: initialQueueCapacity)
    }
}

// MARK: ChannelInboundHandler

extension RedisCommandHandler: ChannelInboundHandler {
    public typealias InboundIn = RESPValue

    /// Invoked by SwiftNIO when an error has been thrown. The command queue will be drained, with each promise in the queue being failed with the error thrown.
    ///
    /// See `NIO.ChannelInboundHandler.errorCaught(context:error:)`
    /// - Important: This will also close the socket connection to Redis.
    /// - Note:`RedisMetrics.commandFailureCount` is **not** incremented from this error.
    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        let queue = self.responseQueue
        
        self.responseQueue.removeAll()
        queue.forEach { $0.fail(error) }

        context.close(promise: nil)
    }

    /// Invoked by SwiftNIO when a read has been fired from earlier in the response chain.
    /// This forwards the decoded `RESPValue` response message to the promise waiting to be fulfilled at the front of the command queue.
    /// - Note: `RedisMetrics.commandFailureCount` and `RedisMetrics.commandSuccessCount` are incremented from this method.
    ///
    /// See `NIO.ChannelInboundHandler.channelRead(context:data:)`
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let value = self.unwrapInboundIn(data)

        guard let leadPromise = self.responseQueue.popFirst() else { return }

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
    public typealias OutboundIn = (data: RESPValue, promise: ResponsePromise)
    public typealias OutboundOut = RESPValue

    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let request = self.unwrapOutboundIn(data)

        self.responseQueue.append(request.promise)

        context.write(self.wrapOutboundOut(request.data), promise: promise)
    }
}
