//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2020 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIO
import Logging
@testable import RediStack
import RediStackTestUtils
import XCTest

final class RedisConnectionPoolTests: RediStackConnectionPoolIntegrationTestCase {
    func test_basicPooledOperation() throws {
        // We're going to insert a bunch of elements into a set, and then when all is done confirm that every
        // element exists.
        let operations = (0..<50).map { number in
            self.pool.sadd([number], to: #function)
        }
        let results = try EventLoopFuture<Int>.whenAllSucceed(operations, on: self.eventLoopGroup.next()).wait()
        XCTAssertEqual(results, Array(repeating: 1, count: 50))
        let whatRedisThinks = try self.pool.smembers(of: #function, as: Int.self).wait()
        XCTAssertEqual(whatRedisThinks.compactMap { $0 }.sorted(), Array(0..<50))
    }

    func test_closedPoolDoesNothing() throws {
        self.pool.close()
        XCTAssertThrowsError(try self.pool.increment(#function).wait()) { error in
            XCTAssertEqual(error as? RedisConnectionPoolError, .poolClosed)
        }
    }
}
