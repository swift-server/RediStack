//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2019 RediStack project authors
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

final class BasicCommandsTests: RediStackIntegrationTestCase {
    func test_select() {
        XCTAssertNoThrow(try connection.select(database: 3).wait())
    }

    func test_delete() throws {
        let keys = [ #function + "1", #function + "2", #function + "3" ].map(RedisKey.init(_:))
        try connection.set(keys[0], to: "value").wait()
        try connection.set(keys[1], to: "value").wait()
        try connection.set(keys[2], to: "value").wait()

        let first = try connection.delete([keys[0]]).wait()
        XCTAssertEqual(first, 1)

        let second = try connection.delete([keys[0]]).wait()
        XCTAssertEqual(second, 0)

        let third = try connection.delete(keys[1], keys[2]).wait()
        XCTAssertEqual(third, 2)
    }

    func test_exists() throws {
        try self.connection.set("first", to: "1").wait()
        let first = try connection.exists("first").wait()
        XCTAssertEqual(first, 1)

        try self.connection.set("second", to: "2").wait()
        let firstAndSecond = try connection.exists("first", "second").wait()
        XCTAssertEqual(firstAndSecond, 2)

        let secondAndThird = try connection.exists("second", "third").wait()
        XCTAssertEqual(secondAndThird, 1)

        let third = try connection.exists("third").wait()
        XCTAssertEqual(third, 0)
    }

    func test_expire() throws {
        try connection.set(#function, to: "value").wait()
        XCTAssertNotNil(try connection.get(#function).wait())
        XCTAssertTrue(try connection.expire(#function, after: .nanoseconds(1)).wait())
        XCTAssertEqual(try connection.get(#function).wait(), .null)
        
        try connection.set(#function, to: "new value").wait()
        XCTAssertNotNil(try connection.get(#function).wait())
        XCTAssertTrue(try connection.expire(#function, after: .seconds(10)).wait())
        XCTAssertNotNil(try connection.get(#function).wait())
    }

    func test_ping() throws {
        let first = try connection.ping().wait()
        XCTAssertEqual(first, "PONG")

        let second = try connection.ping(with: "My message").wait()
        XCTAssertEqual(second, "My message")
    }

    func test_echo() throws {
        let response = try connection.echo("FIZZ_BUZZ").wait()
        XCTAssertEqual(response, "FIZZ_BUZZ")
    }

    func test_swapDatabase() throws {
        try connection.set("first", to: "3").wait()
        var first = try connection.get("first", as: String.self).wait()
        XCTAssertEqual(first, "3")

        try connection.select(database: 1).wait()
        var second = try connection.get("first", as: String.self).wait()
        XCTAssertEqual(second, nil)

        try connection.set("second", to: "100").wait()
        second = try connection.get("second", as: String.self).wait()
        XCTAssertEqual(second, "100")

        let success = try connection.swapDatabase(0, with: 1).wait()
        XCTAssertEqual(success, true)

        second = try connection.get("first", as: String.self).wait()
        XCTAssertEqual(second, "3")

        try connection.select(database: 0).wait()
        first = try connection.get("second", as: String.self).wait()
        XCTAssertEqual(first, "100")
    }

    // TODO: #23 -- Rework Scan Unit Test
    // This is extremely flakey, and causes non-deterministic failures because of the assert on key counts
//    func test_scan() throws {
//        var dataset: [RedisKey] = .init(repeating: "", count: 10)
//        for index in 1...15 {
//            let key = RedisKey("key\(index)\(index % 2 == 0 ? "_even" : "_odd")")
//            dataset.append(key)
//            _ = try connection.set(key, to: "\(index)").wait()
//        }
//
//        var (cursor, keys) = try connection.scan(count: 5).wait()
//        XCTAssertGreaterThanOrEqual(cursor, 0)
//        XCTAssertGreaterThanOrEqual(keys.count, 5)
//
//        (_, keys) = try connection.scan(startingFrom: cursor, count: 8).wait()
//        XCTAssertGreaterThanOrEqual(keys.count, 8)
//
//        (cursor, keys) = try connection.scan(matching: "*_odd").wait()
//        XCTAssertGreaterThanOrEqual(cursor, 0)
//        XCTAssertGreaterThanOrEqual(keys.count, 1)
//        XCTAssertLessThanOrEqual(keys.count, 7)
//
//        (cursor, keys) = try connection.scan(matching: "*_even*").wait()
//        XCTAssertGreaterThanOrEqual(cursor, 0)
//        XCTAssertGreaterThanOrEqual(keys.count, 1)
//        XCTAssertLessThanOrEqual(keys.count, 7)
//    }
}
