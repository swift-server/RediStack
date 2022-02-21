//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2019-2020 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import RediStack
import RediStackTestUtils
import XCTest

final class StringCommandsTests: RediStackIntegrationTestCase {
    private static let testKey = "SortedSetCommandsTests"

    func test_get() throws {
        try connection.set(#function, to: "value").wait()
        let r1: String? = try connection.get(#function, as: String.self).wait()
        XCTAssertEqual(r1, "value")

        try connection.set(#function, to: 30).wait()
        let r2 = try connection.get(#function, as: Int.self).wait()
        XCTAssertEqual(r2, 30)

        _ = try connection.delete(#function).wait()
        let r3: RESPValue? = try connection.get(#function).wait()
        XCTAssertNil(r3)
    }

    func test_mget() throws {
        let keys = ["one", "two"].map(RedisKey.init(_:))
        try keys.forEach { _ = try connection.set($0, to: $0).wait() }

        let values = try connection.send(.mget(keys + ["empty"])).wait()
        XCTAssertEqual(values.count, 3)
        XCTAssertEqual(values[0]?.string, "one")
        XCTAssertEqual(values[1]?.string, "two")
        XCTAssertNil(values[2])

        XCTAssertEqual(try connection.send(.mget("empty", #function)).wait().count, 2)
    }

    func test_set() throws {
        XCTAssertNoThrow(try connection.set(#function, to: "value").wait())
        let val = try connection.get(#function, as: String.self).wait()
        XCTAssertEqual(val, "value")
    }

    func test_set_condition() throws {
        XCTAssertEqual(try connection.set(#function, to: "value", onCondition: .keyExists).wait(), .conditionNotMet)
        XCTAssertEqual(try connection.set(#function, to: "value", onCondition: .keyDoesNotExist).wait(), .ok)
        XCTAssertEqual(try connection.set(#function, to: "value", onCondition: .keyDoesNotExist).wait(), .conditionNotMet)
        XCTAssertEqual(try connection.set(#function, to: "value", onCondition: .keyExists).wait(), .ok)
        XCTAssertEqual(try connection.set(#function, to: "value", onCondition: .none).wait(), .ok)
    }

    func test_set_expiration() throws {
        let expireInSecondsKey = RedisKey("\(#function)-seconds")
        let expireInSecondsResult = connection.set(
            expireInSecondsKey,
            to: "value",
            onCondition: .none,
            expiration: .seconds(42)
        )
        XCTAssertEqual(try expireInSecondsResult.wait(), .ok)

        let ttl = try connection.send(.ttl(expireInSecondsKey)).wait()
        switch ttl {
        case .keyDoesNotExist, .unlimited:
            XCTFail("Unexpected TTL for key \(expireInSecondsKey)")
        case .limited(let lifetime):
            XCTAssertGreaterThan(lifetime.timeAmount, .nanoseconds(0))
            XCTAssertLessThanOrEqual(lifetime.timeAmount, .seconds(42))
        }

        let expireInMillisecondsKey = RedisKey("\(#function)-milliseconds")
        let expireInMillisecondsResult = connection.set(
            expireInMillisecondsKey,
            to: "value",
            onCondition: .none,
            expiration: .milliseconds(42_000)
        )

        XCTAssertEqual(try expireInMillisecondsResult.wait(), .ok)

        let pttl = try connection.send(.ttl(expireInMillisecondsKey)).wait()
        switch pttl {
        case .keyDoesNotExist, .unlimited:
            XCTFail("Unexpected TTL for key \(expireInMillisecondsKey)")
        case .limited(let lifetime):
            XCTAssertGreaterThan(lifetime.timeAmount, .nanoseconds(0))
            XCTAssertLessThanOrEqual(lifetime.timeAmount, .milliseconds(42_000))
        }
    }

    func test_set_condition_and_expiration() throws {
        let setFailedResult = connection.set(#function, to: "value", onCondition: .keyExists, expiration: .seconds(42))
        XCTAssertEqual(try setFailedResult.wait(), .conditionNotMet)

        let setResult = connection.set(#function, to: "value", onCondition: .keyDoesNotExist, expiration: .seconds(42))
        XCTAssertEqual(try setResult.wait(), .ok)

        let ttl = try connection.send(.ttl(#function)).wait()
        switch ttl {
        case .keyDoesNotExist, .unlimited:
            XCTFail("Unexpected TTL for key \(#function)")
        case .limited(let lifetime):
            XCTAssertGreaterThan(lifetime.timeAmount, .nanoseconds(0))
            XCTAssertLessThanOrEqual(lifetime.timeAmount, .seconds(42))
        }
    }

    func test_setnx() throws {
        XCTAssertTrue(try connection.send(.setnx(#function, to: "value")).wait())
        XCTAssertFalse(try connection.send(.setnx(#function, to: "value")).wait())
    }

    func test_setex() throws {
        XCTAssertNoThrow(try connection.send(.setex(#function, to: "value", expirationInSeconds: 42)).wait())
        let ttl = try connection.send(.ttl(#function)).wait()
        switch ttl {
        case .keyDoesNotExist, .unlimited:
            XCTFail("Unexpected TTL for \(#function)")
        case .limited(let lifetime):
            XCTAssertGreaterThan(lifetime.timeAmount, .nanoseconds(0))
            XCTAssertLessThanOrEqual(lifetime.timeAmount, .seconds(42))
        }
    }

    func test_psetex() throws {
        XCTAssertNoThrow(try connection.send(.psetex(#function, to: "value", expirationInMilliseconds: 42_000)).wait())
        let ttl = try connection.send(.pttl(#function)).wait()
        switch ttl {
        case .keyDoesNotExist, .unlimited:
            XCTFail("Unexpected TTL for \(#function)")
        case .limited(let lifetime):
            XCTAssertGreaterThan(lifetime.timeAmount, .nanoseconds(0))
            XCTAssertLessThanOrEqual(lifetime.timeAmount, .milliseconds(42_000))
        }
    }

    func test_append() throws {
        let result = "value appended"
        XCTAssertNoThrow(try connection.send(.append("value", to: #function)).wait())
        let length = try connection.send(.append(" appended", to: #function)).wait()
        XCTAssertEqual(length, result.count)
        let val = try connection.get(#function, as: String.self).wait()
        XCTAssertEqual(val, result)
    }

    func test_mset() throws {
        let data: [RedisKey: Int] = [
            "first": 1,
            "second": 2
        ]
        XCTAssertNoThrow(try connection.send(.mset(data)).wait())
        let values = try connection.send(.mget(["first", "second"])).wait().compactMap { $0?.string }
        XCTAssertEqual(values.count, 2)
        XCTAssertEqual(values[0], "1")
        XCTAssertEqual(values[1], "2")

        XCTAssertNoThrow(try connection.send(.mset(["first": 10])).wait())
        let val = try connection.get("first", as: String.self).wait()
        XCTAssertEqual(val, "10")
    }

    func test_msetnx() throws {
        let data: [RedisKey: Int] = [
            "first": 1,
            "second": 2
        ]
        var success = try connection.send(.msetnx(data)).wait()
        XCTAssertEqual(success, true)

        success = try connection.send(.msetnx(["first": 10, "second": 20])).wait()
        XCTAssertEqual(success, false)

        let values = try connection.send(.mget(["first", "second"])).wait().compactMap { $0?.string }
        XCTAssertEqual(values[0], "1")
        XCTAssertEqual(values[1], "2")
    }

    func test_increment() throws {
        var result = try connection.send(.incr(#function)).wait()
        XCTAssertEqual(result, 1)
        result = try connection.send(.incr(#function)).wait()
        XCTAssertEqual(result, 2)
    }

    func test_incrementBy() throws {
        var result = try connection.send(.incrby(#function, by: 10)).wait()
        XCTAssertEqual(result, 10)
        result = try connection.send(.incrby(#function, by: -3)).wait()
        XCTAssertEqual(result, 7)
        result = try connection.send(.incrby(#function, by: 0)).wait()
        XCTAssertEqual(result, 7)
    }

    func test_incrementByFloat() throws {
        var float = try connection.send(.incrbyfloat(#function, by: Float(3.0))).wait()
        XCTAssertEqual(float, 3.0)
        float = try connection.send(.incrbyfloat(#function, by: Float(-10.135901))).wait()
        XCTAssertEqual(float, -7.135901)

        var double = try connection.send(.incrbyfloat(#function, by: Double(10.2839))).wait()
        XCTAssertEqual(double, 3.147999)
        double = try connection.send(.incrbyfloat(#function, by: Double(15.2938))).wait()
        XCTAssertEqual(double, 18.441799)
    }

    func test_decrement() throws {
        var result = try connection.send(.decr(#function)).wait()
        XCTAssertEqual(result, -1)
        result = try connection.send(.decr(#function)).wait()
        XCTAssertEqual(result, -2)
    }

    func test_decrementBy() throws {
        var result = try connection.send(.decrby(#function, by: -10)).wait()
        XCTAssertEqual(result, 10)
        result = try connection.send(.decrby(#function, by: 3)).wait()
        XCTAssertEqual(result, 7)
        result = try connection.send(.decrby(#function, by: 0)).wait()
        XCTAssertEqual(result, 7)
    }
  
    func test_strlen() throws {
        XCTAssertNoThrow(try connection.set(#function, to: "value").wait())
        let val = try connection.send(.strln(#function)).wait()
        XCTAssertEqual(val, 5)
    }
}
