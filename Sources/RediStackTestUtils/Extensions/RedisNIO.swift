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

import Foundation
import NIO
import RediStack

extension RedisConnection {
    /// Creates a connection intended for tests using `REDIS_URL` and `REDIS_PW` environment variables if available.
    ///
    /// The default URL is `127.0.0.1` while the default port is `RedisConnection.defaultPort`.
    ///
    /// If `REDIS_PW` is not defined, no authentication will happen on the connection.
    /// - Parameters:
    ///     - eventLoop: The event loop that the connection should execute on.
    ///     - port: The port to connect on.
    /// - Returns: A `NIO.EventLoopFuture` that resolves with the new connection.
    public static func connect(
        on eventLoop: EventLoop,
        port: Int = RedisConnection.defaultPort
    ) -> EventLoopFuture<RedisConnection> {
        let env = ProcessInfo.processInfo.environment
        let host = env["REDIS_URL"] ?? "127.0.0.1"
        
        let address: SocketAddress
        do {
            address = try SocketAddress.makeAddressResolvingHost(host, port: port)
        } catch {
            return eventLoop.makeFailedFuture(error)
        }
        
        return RedisConnection.connect(to: address, on: eventLoop, password: env["REDIS_PW"])
    }
}
