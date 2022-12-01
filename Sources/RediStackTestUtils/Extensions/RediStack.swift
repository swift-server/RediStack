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

import Foundation
import Logging
import NIOCore
import RediStack

extension RedisConnection.Configuration {
    /// A default hostname of `localhost` to try and connect to Redis at.
    public static let defaultHostname = "localhost"

    public init(
        host: String = RedisConnection.Configuration.defaultHostname,
        port: Int = RedisConnection.Configuration.defaultPort,
        password: String? = nil,
        defaultLogger: Logger? = nil
    ) throws {
        try self.init(hostname: host, port: port, password: password, defaultLogger: defaultLogger)
    }
}

extension RedisCommand {
    /// Erases all data on the Redis instance.
    /// - Warning: **ONLY** use this on your test Redis instances!
    public static var flushall: RedisCommand<Void> { .init(keyword: "FLUSHALL", arguments: []) }
}
