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

final class HashCommandsTests: RediStackIntegrationTestCase {
    func test_hset() throws {
        var result = try connection.send(.hset("test", to: "\(#line)", in: #function)).wait()
        XCTAssertTrue(result)
        result = try connection.send(.hset("test", to: "\(#line)", in: #function)).wait()
        XCTAssertFalse(result)
    }

    func test_hmset() throws {
        XCTAssertNoThrow(try connection.send(.hmset(["field": 30], in: #function)).wait())
        let value = try connection.send(.hget("field", from: #function)).wait()
        XCTAssertEqual(value?.string, "30")
    }

    func test_hsetnx() throws {
        var success = try connection.send(.hsetnx("field", to: "foo", in: #function)).wait()
        XCTAssertTrue(success)
        success = try connection.send(.hsetnx("field", to: 30, in: #function)).wait()
        XCTAssertFalse(success)

        let value = try connection.send(.hget("field", from: #function)).wait()
        XCTAssertEqual(value?.string, "foo")
    }

    func test_hget() throws {
        _ = try connection.send(.hset("test", to: 30, in: #function)).wait()
        let value = try connection.send(.hget("test", from: #function)).wait()
        XCTAssertEqual(value?.string, "30")
    }

    func test_hmget() throws {
        _ = try connection.send(.hmset(["first": "foo", "second": "bar"], in: #function)).wait()
        let values = try connection.send(.hmget("first", "second", "fake", from: #function)).wait().map { $0.string }
        XCTAssertEqual(values[0], "foo")
        XCTAssertEqual(values[1], "bar")
        XCTAssertNil(values[2])
    }

    func test_hgetall() throws {
        let dataset: [RedisHashFieldKey: RESPValue] = ["first": .init(bulk: "foo"), "second": .init(bulk: "bar")]
        _ = try connection.send(.hmset(dataset, in: #function)).wait()
        let hashes = try connection.send(.hgetall(from: #function)).wait()
        XCTAssertEqual(hashes, dataset)
    }

    func test_hdel() throws {
        _ = try connection.send(.hmset(["first": "foo", "second": "bar"], in: #function)).wait()
        let count = try connection.send(.hdel("first", "second", "fake", from: #function)).wait()
        XCTAssertEqual(count, 2)
    }

    func test_hexists() throws {
        var exists = try connection.send(.hexists("foo", in: #function)).wait()
        XCTAssertFalse(exists)
        _ = try connection.send(.hset("foo", to: "\(#line)", in: #function)).wait()
        exists = try connection.send(.hexists("foo", in: #function)).wait()
        XCTAssertTrue(exists)
    }

    func test_hlen() throws {
        var count = try connection.send(.hlen(of: #function)).wait()
        XCTAssertEqual(count, 0)
        _ = try connection.send(.hset("first", to: "\(#line)", in: #function)).wait()
        count = try connection.send(.hlen(of: #function)).wait()
        XCTAssertEqual(count, 1)
        _ = try connection.send(.hset("second", to: "\(#line)", in: #function)).wait()
        count = try connection.send(.hlen(of: #function)).wait()
        XCTAssertEqual(count, 2)
    }

    func test_hstrlen() throws {
        _ = try connection.send(.hset("first", to: "foo", in: #function)).wait()
        var size = try connection.send(.hstrlen(of: "first", in: #function)).wait()
        XCTAssertEqual(size, 3)
        _ = try connection.send(.hset("second", to: 300, in: #function)).wait()
        size = try connection.send(.hstrlen(of: "second", in: #function)).wait()
        XCTAssertEqual(size, 3)
    }

    func test_hkeys() throws {
        let dataset: [RedisHashFieldKey: String] = [
            "first": "3",
            "second": "foo"
        ]
        _ = try connection.send(.hmset(dataset, in: #function)).wait()
        let keys = try connection.send(.hkeys(in: #function)).wait()
        XCTAssertEqual(keys.count, 2)
        XCTAssertTrue(keys.allSatisfy(dataset.keys.contains))
    }

    func test_hvals() throws {
        let dataset: [RedisHashFieldKey: String] = [
            "first": "3",
            "second": "foo"
        ]
        _ = try connection.send(.hmset(dataset, in: #function)).wait()
        let values = try connection.send(.hvals(in: #function)).wait().compactMap { String(fromRESP: $0) }
        XCTAssertEqual(values.count, 2)
        XCTAssertTrue(values.allSatisfy(dataset.values.contains))
    }

    func test_hincrby() throws {
        _ = try connection.send(.hset("first", to: 3, in: #function)).wait()
        var value = try connection.send(.hincrby(10, field: "first", in: #function)).wait()
        XCTAssertEqual(value, 13)
        value = try connection.send(.hincrby(-15, field: "first", in: #function)).wait()
        XCTAssertEqual(value, -2)
    }

    func test_hincrbyfloat() throws {
        _ = try connection.send(.hset("first", to: 3.14, in: #function)).wait()

        let double = try connection.send(.hincrbyfloat(Double(3.14), field: "first", in: #function)).wait()
        XCTAssertEqual(double, 6.28)

        let float = try connection.send(.hincrbyfloat(Float(-10.23523), field: "first", in: #function)).wait()
        XCTAssertEqual(float, -3.95523)
    }
    
    // TODO: #23 -- Rework Scan Unit Test
    // This is extremely flakey, and causes non-deterministic failures because of the assert on key counts
//    func test_hscan() throws {
//        var dataset: [String: String] = [:]
//        for index in 1...15 {
//            let key = "key\(index)\(index % 2 == 0 ? "_even" : "_odd")"
//            dataset[key] = "\(index)"
//        }
//        _ = try connection.hmset(dataset, in: #function).wait()
//
//        var (cursor, fields) = try connection.hscan(#function, count: 5).wait()
//        XCTAssertGreaterThanOrEqual(cursor, 0)
//        XCTAssertGreaterThanOrEqual(fields.count, 5)
//
//        (_, fields) = try connection.hscan(#function, startingFrom: cursor, count: 8).wait()
//        XCTAssertGreaterThanOrEqual(fields.count, 8)
//
//        (cursor, fields) = try connection.hscan(#function, matching: "*_odd").wait()
//        XCTAssertGreaterThanOrEqual(cursor, 0)
//        XCTAssertGreaterThanOrEqual(fields.count, 1)
//        XCTAssertLessThanOrEqual(fields.count, 8)
//
//        (cursor, fields) = try connection.hscan(#function, matching: "*_ev*").wait()
//        XCTAssertGreaterThanOrEqual(cursor, 0)
//        XCTAssertGreaterThanOrEqual(fields.count, 1)
//        XCTAssertLessThanOrEqual(fields.count, 7)
//    }
}
