//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2020 Apple Inc. and the RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOCore
import RediStack

extension RedisConnection {
    /// A default hostname of `localhost` to try and connect to Redis at.
    @available(*, deprecated, message: "Use RedisConnection.Configuration.defaultHostname")
    public static let defaultHostname = "localhost"

    /// Creates a connection intended for tests using `REDIS_URL` and `REDIS_PW` environment variables if available.
    ///
    /// The default URL is `127.0.0.1` while the default port is `RedisConnection.defaultPort`.
    ///
    /// If `REDIS_PW` is not defined, no authentication will happen on the connection.
    /// - Parameters:
    ///     - eventLoop: The event loop that the connection should execute on.
    ///     - port: The port to connect on.
    /// - Returns: A `NIO.EventLoopFuture` that resolves with the new connection.
    @available(*, deprecated, message: "Use RedisConnection.make(configuration:boundEventLoop:) method")
    public static func connect(
        on eventLoop: EventLoop,
        host: String = RedisConnection.defaultHostname,
        port: Int = RedisConnection.Configuration.defaultPort,
        password: String? = nil
    ) -> EventLoopFuture<RedisConnection> {
        let address: SocketAddress
        do {
            address = try SocketAddress.makeAddressResolvingHost(host, port: port)
        } catch {
            return eventLoop.makeFailedFuture(error)
        }

        return RedisConnection.connect(to: address, on: eventLoop, password: password)
    }
}
