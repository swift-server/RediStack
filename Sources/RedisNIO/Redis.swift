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

import struct Logging.Logger
import NIO

/// Top-level namespace for the `RedisNIO` package.
///
/// To avoid a cluttered global namespace, named definitions that do not start with a `Redis` prefix
/// are scoped within this namespace.
public enum Redis { }

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
    ///         to: .init(ipAddress: "127.0.0.1", port: RedisConnection.defaultPort),
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
        logger: Logger = Logger(label: "RedisNIO.RedisConnection")
    ) -> EventLoopFuture<RedisConnection> {
        let client = ClientBootstrap.makeRedisTCPClient(group: group)

        return client.connect(to: socket)
            .map { return RedisConnection(channel: $0, logger: logger) }
            .flatMap { client in
                guard let pw = password else {
                    return group.next().makeSucceededFuture(client)
                }

                let args = [RESPValue(bulk: pw)]
                return client.send(command: "AUTH", with: args)
                    .map { _ in return client }
            }
    }
}
