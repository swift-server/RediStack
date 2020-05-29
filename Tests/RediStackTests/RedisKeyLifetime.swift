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

@testable import RediStack
import XCTest

final class RedisKeyLifetimeTests: XCTestCase {
    func test_initFromSeconds() {
        XCTAssertEqual(RedisKeyLifetime(seconds: -2), .keyDoesNotExist)
        XCTAssertEqual(RedisKeyLifetime(seconds: -1), .unlimited)
        XCTAssertEqual(RedisKeyLifetime(seconds: 42), .limited(.seconds(42)))
    }

    func test_initFromMilliseconds() {
        XCTAssertEqual(RedisKeyLifetime(milliseconds: -2), .keyDoesNotExist)
        XCTAssertEqual(RedisKeyLifetime(milliseconds: -1), .unlimited)
        XCTAssertEqual(RedisKeyLifetime(milliseconds: 42), .limited(.milliseconds(42)))
    }

    func test_timeAmount() {
        XCTAssertNil(RedisKeyLifetime.keyDoesNotExist.timeAmount)
        XCTAssertNil(RedisKeyLifetime.unlimited.timeAmount)

        XCTAssertEqual(RedisKeyLifetime.limited(.seconds(42)).timeAmount, .seconds(42))
        XCTAssertEqual(RedisKeyLifetime.limited(.milliseconds(42)).timeAmount, .milliseconds(42))
    }

    func test_lifetimeCompare() {
        XCTAssertLessThan(RedisKeyLifetime.Lifetime.seconds(42), .seconds(43))
        XCTAssertLessThan(RedisKeyLifetime.Lifetime.seconds(42), .milliseconds(42001))
        XCTAssertLessThan(RedisKeyLifetime.Lifetime.milliseconds(41999), .milliseconds(42000))
        XCTAssertLessThan(RedisKeyLifetime.Lifetime.milliseconds(41999), .seconds(42))
    }

    func test_lifetimeEqual() {
        XCTAssertEqual(RedisKeyLifetime.Lifetime.seconds(42), .seconds(42))
        XCTAssertEqual(RedisKeyLifetime.Lifetime.seconds(42), .milliseconds(42000))
        XCTAssertEqual(RedisKeyLifetime.Lifetime.milliseconds(42000), .milliseconds(42000))
        XCTAssertEqual(RedisKeyLifetime.Lifetime.milliseconds(42000), .seconds(42))
    }
}
