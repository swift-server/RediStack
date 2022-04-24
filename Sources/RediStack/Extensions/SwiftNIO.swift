//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2019-2022 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIO

// MARK: Convenience extensions

extension TimeAmount {
    /// The seconds representation of the TimeAmount.
    @usableFromInline
    internal var seconds: Int64 {
        return self.nanoseconds / 1_000_000_000
    }
}

// MARK: Pipeline manipulation

extension ChannelPipeline {
    /// Adds the baseline channel handlers needed to support sending and receiving messages in Redis Serialization Protocol (RESP) format to the pipeline.
    ///
    /// For implementation details, see ``RedisMessageEncoder``, ``RedisByteDecoder``, and ``RedisCommandHandler``.
    ///
    /// # Pipeline chart
    ///                                                 RedisClient.send
    ///                                                         |
    ///                                                         v
    ///     +-------------------------------------------------------------------+
    ///     |                           ChannelPipeline         |               |
    ///     |                                TAIL               |               |
    ///     |    +---------------------------------------------------------+    |
    ///     |    |                  RedisCommandHandler                    |    |
    ///     |    +---------------------------------------------------------+    |
    ///     |               ^                                   |               |
    ///     |               |                                   v               |
    ///     |    +---------------------+            +----------------------+    |
    ///     |    |  RedisByteDecoder   |            |  RedisMessageEncoder |    |
    ///     |    +---------------------+            +----------------------+    |
    ///     |               |                                   |               |
    ///     |               |              HEAD                 |               |
    ///     +-------------------------------------------------------------------+
    ///                     ^                                   |
    ///                     |                                   v
    ///             +-----------------+                +------------------+
    ///             | [ Socket.read ] |                | [ Socket.write ] |
    ///             +-----------------+                +------------------+
    /// - Returns: A `NIO.EventLoopFuture` that resolves after all handlers have been added to the pipeline.
    public func addBaseRedisHandlers() -> EventLoopFuture<Void> {
        let handlers: [(ChannelHandler, name: String)] = [
            (MessageToByteHandler(RedisMessageEncoder()), "RediStack.OutgoingHandler"),
            (ByteToMessageHandler(RedisByteDecoder()), "RediStack.IncomingHandler"),
            (RedisCommandHandler(), "RediStack.CommandHandler")
        ]
        return .andAllSucceed(
            handlers.map { self.addHandler($0, name: $1) },
            on: self.eventLoop
        )
    }
    
    /// Adds the channel handler that is responsible for handling everything related to Redis PubSub.
    /// - Important: The connection that manages this channel is responsible for removing the ``RedisPubSubHandler``.
    ///
    /// # Discussion
    /// PubSub responsibilities include managing subscription callbacks as well as parsing and dispatching messages received from Redis.
    ///
    /// For implementation details, see ``RedisPubSubHandler``.
    ///
    /// The handler will be inserted in the `NIO.ChannelPipeline` just before the ``RedisCommandHandler`` instance.
    ///
    /// # Pipeline chart
    ///                                                 RedisClient.send
    ///                                                         |
    ///                                                         v
    ///     +-------------------------------------------------------------------+
    ///     |                           ChannelPipeline         |               |
    ///     |                                TAIL               |               |
    ///     |    +---------------------------------------------------------+    |
    ///     |    |                  RedisCommandHandler                    |    |
    ///     |    +---------------------------------------------------------+    |
    ///     |               ^                                   |               |
    ///     |               |                                   v               |
    ///     |    +---------------------------------------------------------+    |
    ///     |    | (might forward)    RedisPubSubHandler     (forwards)    |----|<-----------+
    ///     |    +---------------------------------------------------------+    |            |
    ///     |               ^                                   |               |            +
    ///     |               |                                   v               | RedisClient.subscribe/unsubscribe
    ///     |    +---------------------+            +----------------------+    |
    ///     |    |  RedisByteDecoder   |            |  RedisMessageEncoder |    |
    ///     |    +---------------------+            +----------------------+    |
    ///     |               |                                   |               |
    ///     |               |              HEAD                 |               |
    ///     +-------------------------------------------------------------------+
    ///                     ^                                   |
    ///                     |                                   v
    ///             +-----------------+                +------------------+
    ///             | [ Socket.read ] |                | [ Socket.write ] |
    ///             +-----------------+                +------------------+
    /// - Returns: A `NIO.EventLoopFuture` that resolves the instance of the PubSubHandler that was added to the pipeline.
    public func addRedisPubSubHandler() -> EventLoopFuture<RedisPubSubHandler> {
        // first try to return the handler that already exists in the pipeline

        return self.handler(type: RedisPubSubHandler.self)
            .flatMapError {
                // if it doesn't exist, add it to the pipeline
                guard
                    let error = $0 as? ChannelPipelineError,
                    error == .notFound
                else { return self.eventLoop.makeFailedFuture($0) }

                return self.handler(type: RedisCommandHandler.self)
                    .flatMap {
                        let pubsubHandler = RedisPubSubHandler(eventLoop: self.eventLoop)
                        return self.addHandler(pubsubHandler, name: "RediStack.PubSubHandler", position: .before($0))
                            .map { pubsubHandler }
                    }
            }
    }

    /// Removes the provided Redis PubSub handler.
    /// - Returns: A `NIO.EventLoopFuture` that resolves when the handler was removed from the pipeline.
    public func removeRedisPubSubHandler(_ handler: RedisPubSubHandler) -> EventLoopFuture<Void> {
        self.removeHandler(handler)
            .flatMapError {
                // if it was already removed, then we can just succeed
                guard
                    let error = $0 as? ChannelPipelineError,
                    error == .alreadyRemoved
                else { return self.eventLoop.makeFailedFuture($0) }

                return self.eventLoop.makeSucceededVoidFuture()
            }
    }
}

// MARK: Setting up a Redis connection

extension ClientBootstrap {
    /// Makes a new `ClientBootstrap` instance with a baseline Redis `Channel` pipeline
    /// for sending and receiving messages in Redis Serialization Protocol (RESP) format.
    ///
    /// For implementation details, see ``RedisMessageEncoder``, ``RedisByteDecoder``, and ``RedisCommandHandler``.
    ///
    /// See also `ChannelPipeline.addBaseRedisHandlers()`.
    /// - Parameter group: The `EventLoopGroup` to create the `ClientBootstrap` with.
    /// - Returns: A TCP connection with the base configuration of a `Channel` pipeline for RESP messages.
    public static func makeRedisTCPClient(group: EventLoopGroup) -> ClientBootstrap {
        return ClientBootstrap(group: group)
            .channelOption(
                ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR),
                value: 1
            )
            .channelInitializer { $0.pipeline.addBaseRedisHandlers() }
    }
}
