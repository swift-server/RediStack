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

import XCTest

@testable import RediStack

final class RedisKeyLifetimeTests: XCTestCase {
    func test_initFromSeconds() {
        XCTAssertEqual(RedisKey.Lifetime(seconds: -2), .keyDoesNotExist)
        XCTAssertEqual(RedisKey.Lifetime(seconds: -1), .unlimited)
        XCTAssertEqual(RedisKey.Lifetime(seconds: 42), .limited(.seconds(42)))
    }

    func test_initFromMilliseconds() {
        XCTAssertEqual(RedisKey.Lifetime(milliseconds: -2), .keyDoesNotExist)
        XCTAssertEqual(RedisKey.Lifetime(milliseconds: -1), .unlimited)
        XCTAssertEqual(RedisKey.Lifetime(milliseconds: 42), .limited(.milliseconds(42)))
    }

    func test_timeAmount() {
        XCTAssertNil(RedisKey.Lifetime.keyDoesNotExist.timeAmount)
        XCTAssertNil(RedisKey.Lifetime.unlimited.timeAmount)

        XCTAssertEqual(RedisKey.Lifetime.limited(.seconds(42)).timeAmount, .seconds(42))
        XCTAssertEqual(RedisKey.Lifetime.limited(.milliseconds(42)).timeAmount, .milliseconds(42))
    }

    func test_lifetimeCompare() {
        XCTAssertLessThan(RedisKey.Lifetime.Duration.seconds(42), .seconds(43))
        XCTAssertLessThan(RedisKey.Lifetime.Duration.seconds(42), .milliseconds(42001))
        XCTAssertLessThan(RedisKey.Lifetime.Duration.milliseconds(41999), .milliseconds(42000))
        XCTAssertLessThan(RedisKey.Lifetime.Duration.milliseconds(41999), .seconds(42))
    }

    func test_lifetimeEqual() {
        XCTAssertEqual(RedisKey.Lifetime.Duration.seconds(42), .seconds(42))
        XCTAssertEqual(RedisKey.Lifetime.Duration.seconds(42), .milliseconds(42000))
        XCTAssertEqual(RedisKey.Lifetime.Duration.milliseconds(42000), .milliseconds(42000))
        XCTAssertEqual(RedisKey.Lifetime.Duration.milliseconds(42000), .seconds(42))
    }
}
