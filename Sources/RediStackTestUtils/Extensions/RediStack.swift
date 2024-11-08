//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2019-2020 Apple Inc. and the RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import NIOCore
import RediStack

extension RedisConnection.Configuration {
    /// A default hostname of `localhost` to try and connect to Redis at.
    public static let defaultHostname = "localhost"

    public init(
        host: String = RedisConnection.Configuration.defaultHostname,
        port: Int = RedisConnection.Configuration.defaultPort,
        password: String? = nil
    ) throws {
        try self.init(hostname: host, port: port, password: password)
    }
}
