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

import RediStack
import RediStackTestUtils
import XCTest

final class KeyCommandsTests: RediStackIntegrationTestCase {
    func test_delete() throws {
        let keys = [ #function + "1", #function + "2", #function + "3" ].map(RedisKey.init(_:))
        try connection.send(.set(keys[0], to: "value")).wait()
        try connection.send(.set(keys[1], to: "value")).wait()
        try connection.send(.set(keys[2], to: "value")).wait()

        let first = try connection.delete([keys[0]]).wait()
        XCTAssertEqual(first, 1)

        let second = try connection.delete([keys[0]]).wait()
        XCTAssertEqual(second, 0)

        let third = try connection.delete(keys[1], keys[2]).wait()
        XCTAssertEqual(third, 2)
    }

    func test_exists() throws {
        try self.connection.send(.set("first", to: "1")).wait()
        let first = try connection.send(.exists("first")).wait()
        XCTAssertEqual(first, 1)

        try self.connection.send(.set("second", to: "2")).wait()
        let firstAndSecond = try connection.send(.exists("first", "second")).wait()
        XCTAssertEqual(firstAndSecond, 2)

        let secondAndThird = try connection.send(.exists("second", "third")).wait()
        XCTAssertEqual(secondAndThird, 1)

        let third = try connection.send(.exists("third")).wait()
        XCTAssertEqual(third, 0)
    }

    func test_expire() throws {
        try connection.set(#function, to: "value").wait()
        XCTAssertNotNil(try connection.get(#function).wait())
        XCTAssertTrue(try connection.expire(#function, after: .nanoseconds(1)).wait())
        XCTAssertNil(try connection.get(#function).wait())
        
        try connection.set(#function, to: "new value").wait()
        XCTAssertNotNil(try connection.get(#function).wait())
        XCTAssertTrue(try connection.expire(#function, after: .seconds(10)).wait())
        XCTAssertNotNil(try connection.get(#function).wait())
    }

    func test_ttl() throws {
        try self.connection.set("first", to: "value").wait()
        let expire = try self.connection.expire("first", after: .minutes(1)).wait()
        XCTAssertTrue(expire)

        let ttl = try self.connection.send(.ttl("first")).wait()
        switch ttl {
        case .keyDoesNotExist, .unlimited:
            XCTFail("Expected an expiry to be set on key 'first'")
        case .limited(let lifetime):
            XCTAssertGreaterThanOrEqual(lifetime.timeAmount.nanoseconds, 0)
        }

        let doesNotExist = try self.connection.send(.ttl("second")).wait()
        switch doesNotExist {
        case .keyDoesNotExist:
            ()  // Expected
        case .unlimited, .limited:
            XCTFail("Expected '.keyDoesNotExist' but lifetime was \(doesNotExist)")
        }

        try self.connection.set("second", to: "value").wait()
        let hasNoExpire = try self.connection.send(.ttl("second")).wait()
        switch hasNoExpire {
        case .unlimited:
            ()  // Expected
        case .keyDoesNotExist, .limited:
            XCTFail("Expected '.noExpiry' but lifetime was \(hasNoExpire)")
        }
    }

    func test_pttl() throws {
        try self.connection.set("first", to: "value").wait()
        let expire = try self.connection.expire("first", after: .minutes(1)).wait()
        XCTAssertTrue(expire)

        let pttl = try self.connection.send(.pttl("first")).wait()
        switch pttl {
        case .keyDoesNotExist, .unlimited:
            XCTFail("Expected an expiry to be set on key 'first'")
        case .limited(let lifetime):
            XCTAssertGreaterThanOrEqual(lifetime.timeAmount.nanoseconds, 0)
        }

        let doesNotExist = try self.connection.send(.ttl("second")).wait()
        switch doesNotExist {
        case .keyDoesNotExist:
            ()  // Expected
        case .unlimited, .limited:
            XCTFail("Expected '.keyDoesNotExist' but lifetime was \(doesNotExist)")
        }

        try self.connection.set("second", to: "value").wait()
        let hasNoExpire = try self.connection.send(.ttl("second")).wait()
        switch hasNoExpire {
        case .unlimited:
            ()  // Expected
        case .keyDoesNotExist, .limited:
            XCTFail("Expected '.noExpiry' but lifetime was \(hasNoExpire)")
        }
    }

    func test_scan() throws {
        var dataset: [RedisKey] = .init(repeating: "", count: 10)
        for index in 1...15 {
            let key = RedisKey("key\(index)\(index % 2 == 0 ? "_even" : "_odd")")
            dataset.append(key)
            _ = try connection.set(key, to: "\(index)").wait()
        }

        var (cursor, keys) = try connection.scanKeys(count: 5).wait()
        XCTAssertGreaterThanOrEqual(cursor, 0)
        XCTAssertGreaterThanOrEqual(keys.count, 5)

        (_, keys) = try connection.scanKeys(startingFrom: cursor, count: 8).wait()
        XCTAssertGreaterThanOrEqual(keys.count, 8)

        (cursor, keys) = try connection.scanKeys(matching: "*_odd").wait()
        XCTAssertGreaterThanOrEqual(cursor, 0)
        XCTAssertGreaterThanOrEqual(keys.count, 1)
        XCTAssertLessThanOrEqual(keys.count, 8)

        (cursor, keys) = try connection.scanKeys(matching: "*_even*").wait()
        XCTAssertGreaterThanOrEqual(cursor, 0)
        XCTAssertGreaterThanOrEqual(keys.count, 1)
        XCTAssertLessThanOrEqual(keys.count, 7)
    }

    func test_keys() throws {
        let range = Range(0...3)
        try range.forEach {
            try self.connection.set("\(#function)_\($0)", to: $0).wait()
        }
        let keys = try self.connection.listKeys(matching: "\(#function)*").wait()
        XCTAssertEqual(keys.count, range.count)
        XCTAssertTrue(keys.allSatisfy({ $0.rawValue.contains(#function) }))
    }
}
