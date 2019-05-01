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

@testable import NIORedis

extension Redis {
    static func makeConnection() throws -> EventLoopFuture<RedisConnection> {
        return Redis.makeConnection(
            to: try .init(ipAddress: "127.0.0.1", port: 6379),
            using: MultiThreadedEventLoopGroup(numberOfThreads: 1)
        )
    }
}
