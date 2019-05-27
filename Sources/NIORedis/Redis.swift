//===----------------------------------------------------------------------===//
//
// This source file is part of the NIORedis open source project
//
// Copyright (c) 2019 NIORedis project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of NIORedis project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct Logging.Logger
import NIO

/// Top-level namespace for the `NIORedis` package.
///
/// To avoid a cluttered global namespace, named definitions that do not start with a `Redis` prefix
/// are scoped within this namespace.
public enum Redis { }

// MARK: ClientBootstrap

extension Redis {
    /// Makes a new `ClientBootstrap` instance with a default Redis `Channel` pipeline
    /// for sending and receiving messages in Redis Serialization Protocol (RESP) format.
    ///
    /// See `RedisMessageEncoder`, `RedisByteDecoder`, and `RedisCommandHandler`.
    /// - Parameter using: The `EventLoopGroup` to build the `ClientBootstrap` on.
    /// - Returns: A `ClientBootstrap` with the default configuration of a `Channel` pipeline for RESP messages.
    public static func makeDefaultClientBootstrap(using group: EventLoopGroup) -> ClientBootstrap {
        return ClientBootstrap(group: group)
            .channelOption(
                ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR),
                value: 1
            )
            .channelInitializer { channel in
                let handlers: [(ChannelHandler, String)] = [
                    (MessageToByteHandler(RedisMessageEncoder()), "NIORedis.Outgoing"),
                    (ByteToMessageHandler(RedisByteDecoder()), "NIORedis.Incoming"),
                    (RedisCommandHandler(), "NIORedis.Queue")
                ]
                return .andAllSucceed(
                    handlers.map { channel.pipeline.addHandler($0, name: $1) },
                    on: group.next()
                )
            }
    }
}

// MARK: Connection Factory

extension Redis {
    /// Makes a new connection to a Redis instance.
    ///
    /// As soon as the connection has been opened on the host, an "AUTH" command will be sent to
    /// Redis to authorize use of additional commands on this new connection.
    ///
    /// See [https://redis.io/commands/auth](https://redis.io/commands/auth)
    ///
    /// Example:
    ///
    ///     let elg = MultiThreadedEventLoopGroup(numberOfThreads: 3)
    ///     let connection = Redis.makeConnection(
    ///         to: .init(ipAddress: "127.0.0.1", port: 6379),
    ///         using: elg,
    ///         password: "my_pass"
    ///     )
    ///
    /// - Parameters:
    ///     - socket: The `SocketAddress` information of the Redis instance to connect to.
    ///     - group: The `EventLoopGroup` to build the connection on. Default is a single threaded `EventLoopGroup`.
    ///     - password: The optional password to authorize the client with.
    ///     - logger: The `Logger` instance to log with.
    /// - Returns: A `RedisConnection` instance representing this new connection.
    public static func makeConnection(
        to socket: SocketAddress,
        using group: EventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1),
        password: String? = nil,
        logger: Logger = Logger(label: "NIORedis.RedisConnection")
    ) -> EventLoopFuture<RedisConnection> {
        let bootstrap = makeDefaultClientBootstrap(using: group)

        return bootstrap.connect(to: socket)
            .map { return RedisConnection(channel: $0, logger: logger) }
            .flatMap { client in
                guard let pw = password else {
                    return group.next().makeSucceededFuture(client)
                }

                return client.send(command: "AUTH", with: [pw])
                    .map { _ in return client }
            }
    }
}
