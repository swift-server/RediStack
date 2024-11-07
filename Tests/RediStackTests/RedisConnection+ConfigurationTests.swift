//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2023 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import RediStack
import XCTest

final class RedisConnection_ConfigurationTest: XCTestCase {

    func testGetDefaultRedisPort() {
        XCTAssertEqual(RedisConnection.Configuration.defaultPort, 6379)
    }

    @available(*, deprecated, message: "Testing deprecated functionality")
    func testGetAndSetTheDefaultRedisPort() {
        XCTAssertEqual(RedisConnection.Configuration.defaultPort, 6379)
        RedisConnection.Configuration.defaultPort = 1234
        XCTAssertEqual(RedisConnection.Configuration.defaultPort, 1234)

        // reset the default port
        RedisConnection.Configuration.defaultPort = 6379
    }
}
