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

import Foundation
import NIO
import RedisNIO

extension Redis {
    /// Creates a `RedisConnection` using `REDIS_URL` and `REDIS_PW` environment variables if available.
    ///
    /// The default URL is `127.0.0.1` while the default port is `RedisConnection.defaultPort`.
    ///
    /// If `REDIS_PW` is not defined, no authentication will happen on the connection.
    public static func makeConnection() throws -> EventLoopFuture<RedisConnection> {
        let env = ProcessInfo.processInfo.environment
        return Redis.makeConnection(
            to: try .makeAddressResolvingHost(
                env["REDIS_URL"] ?? "127.0.0.1",
                port: RedisConnection.defaultPort
            ),
            password: env["REDIS_PW"]
        )
    }
}
