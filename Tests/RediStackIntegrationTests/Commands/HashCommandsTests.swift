//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2019 Apple Inc. and the RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import RediStackTestUtils
import XCTest

@testable import RediStack

final class HashCommandsTests: RediStackIntegrationTestCase {
    func test_hset() throws {
        var result = try connection.hset("test", to: "\(#line)", in: #function).wait()
        XCTAssertTrue(result)
        result = try connection.hset("test", to: "\(#line)", in: #function).wait()
        XCTAssertFalse(result)
    }

    func test_hmset() throws {
        XCTAssertNoThrow(try connection.hmset(["field": 30], in: #function).wait())
        let value = try connection.hget("field", from: #function, as: String.self).wait()
        XCTAssertEqual(value, "30")
    }

    func test_hsetnx() throws {
        var success = try connection.hsetnx("field", to: "foo", in: #function).wait()
        XCTAssertTrue(success)
        success = try connection.hsetnx("field", to: 30, in: #function).wait()
        XCTAssertFalse(success)

        let value = try connection.hget("field", from: #function, as: String.self).wait()
        XCTAssertEqual(value, "foo")
    }

    func test_hget() throws {
        _ = try connection.hset("test", to: 30, in: #function).wait()
        let value = try connection.hget("test", from: #function, as: String.self).wait()
        XCTAssertEqual(value, "30")
    }

    func test_hmget() throws {
        _ = try connection.hmset(["first": "foo", "second": "bar"], in: #function).wait()
        let values = try connection.hmget("first", "second", "fake", from: #function, as: String.self).wait()
        XCTAssertEqual(values[0], "foo")
        XCTAssertEqual(values[1], "bar")
        XCTAssertNil(values[2])
    }

    func test_hgetall() throws {
        let dataset = ["first": "foo", "second": "bar"]
        _ = try connection.hmset(dataset, in: #function).wait()
        let hashes = try connection.hgetall(from: #function, as: String.self).wait()
        XCTAssertEqual(hashes, dataset)
    }

    func test_hdel() throws {
        _ = try connection.hmset(["first": "foo", "second": "bar"], in: #function).wait()
        let count = try connection.hdel("first", "second", "fake", from: #function).wait()
        XCTAssertEqual(count, 2)
    }

    func test_hexists() throws {
        var exists = try connection.hexists("foo", in: #function).wait()
        XCTAssertFalse(exists)
        _ = try connection.hset("foo", to: "\(#line)", in: #function).wait()
        exists = try connection.hexists("foo", in: #function).wait()
        XCTAssertTrue(exists)
    }

    func test_hlen() throws {
        var count = try connection.hlen(of: #function).wait()
        XCTAssertEqual(count, 0)
        _ = try connection.hset("first", to: "\(#line)", in: #function).wait()
        count = try connection.hlen(of: #function).wait()
        XCTAssertEqual(count, 1)
        _ = try connection.hset("second", to: "\(#line)", in: #function).wait()
        count = try connection.hlen(of: #function).wait()
        XCTAssertEqual(count, 2)
    }

    func test_hstrlen() throws {
        _ = try connection.hset("first", to: "foo", in: #function).wait()
        var size = try connection.hstrlen(of: "first", in: #function).wait()
        XCTAssertEqual(size, 3)
        _ = try connection.hset("second", to: 300, in: #function).wait()
        size = try connection.hstrlen(of: "second", in: #function).wait()
        XCTAssertEqual(size, 3)
    }

    func test_hkeys() throws {
        let dataset: [String: String] = [
            "first": "3",
            "second": "foo",
        ]
        _ = try connection.hmset(dataset, in: #function).wait()
        let keys = try connection.hkeys(in: #function).wait()
        XCTAssertEqual(keys.count, 2)
        XCTAssertTrue(keys.allSatisfy(dataset.keys.contains))
    }

    func test_hvals() throws {
        let dataset = [
            "first": "3",
            "second": "foo",
        ]
        _ = try connection.hmset(dataset, in: #function).wait()
        let values = try connection.hvals(in: #function).wait().compactMap { String(fromRESP: $0) }
        XCTAssertEqual(values.count, 2)
        XCTAssertTrue(values.allSatisfy(dataset.values.contains))
    }

    func test_hincrby() throws {
        _ = try connection.hset("first", to: 3, in: #function).wait()
        var value = try connection.hincrby(10, field: "first", in: #function).wait()
        XCTAssertEqual(value, 13)
        value = try connection.hincrby(-15, field: "first", in: #function).wait()
        XCTAssertEqual(value, -2)
    }

    func test_hincrbyfloat() throws {
        _ = try connection.hset("first", to: 3.14, in: #function).wait()

        let double = try connection.hincrbyfloat(Double(3.14), field: "first", in: #function).wait()
        XCTAssertEqual(double, 6.28)

        let float = try connection.hincrbyfloat(Float(-10.23523), field: "first", in: #function).wait()
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
