//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2020-2022 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import ServiceDiscovery
import NIO
import Logging
@testable import RediStack
import RediStackTestUtils
import XCTest

final class RedisServiceDiscoveryTests: RediStackConnectionPoolIntegrationTestCase {
    func test_basicServiceDiscovery() throws {
        let hosts = InMemoryServiceDiscovery<String, SocketAddress>(configuration: .init())
        let config = RedisConnectionPool.Configuration(
            initialServerConnectionAddresses: [],
            connectionCountBehavior: .strict(maximumConnectionCount: 5),
            connectionConfiguration: .init(password: self.redisPassword)
        )
        let client = RedisConnectionPool.activatedServiceDiscoveryPool(
            service: "default.local",
            discovery: hosts,
            configuration: config,
            boundEventLoop: self.eventLoopGroup.next()
        )
        defer {
            client.close()
        }

        let address = try SocketAddress.makeAddressResolvingHost(self.redisHostname, port: self.redisPort)
        hosts.register("default.local", instances: [address])
        hosts.register("another.local", instances: [])

        // Now we try to make a bunch of requests.
        // We're going to insert a bunch of elements into a set, and then when all is done confirm that every
        // element exists.
        let operations = (0..<50).map { number in
            client.send(.sadd([number], to: #function))
        }
        let results = try EventLoopFuture<Int>.whenAllSucceed(operations, on: self.eventLoopGroup.next()).wait()
        XCTAssertEqual(results, Array(repeating: 1, count: 50))
        let whatRedisThinks = try client.send(.smembers(of: #function)).wait()
        XCTAssertEqual(whatRedisThinks.compactMap { $0.int }.sorted(), Array(0..<50))
    }
}
