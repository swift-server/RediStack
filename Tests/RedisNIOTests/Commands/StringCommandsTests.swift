//===----------------------------------------------------------------------===//
//
// This source file is part of the RedisNIO open source project
//
// Copyright (c) 2019 RedisNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RedisNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import RedisNIO
import XCTest

final class StringCommandsTests: XCTestCase {
    private static let testKey = "SortedSetCommandsTests"

    private var connection: RedisConnection!

    override func setUp() {
        do {
            connection = try Redis.makeConnection().wait()
        } catch {
            XCTFail("Failed to create RedisConnection! \(error)")
        }
    }

    override func tearDown() {
        _ = try? connection.send(command: "FLUSHALL").wait()
        try? connection.close().wait()
        connection = nil
    }

    func test_get() throws {
        try connection.set(#function, to: "value").wait()
        let result = try connection.get(#function).wait()
        XCTAssertEqual(result, "value")
    }

    func test_mget() throws {
        let keys = ["one", "two"]
        try keys.forEach { _ = try connection.set($0, to: $0).wait() }

        let values = try connection.mget(keys + ["empty"]).wait()
        XCTAssertEqual(values.count, 3)
        XCTAssertEqual(values[0].string, "one")
        XCTAssertEqual(values[1].string, "two")
        XCTAssertEqual(values[2].isNull, true)

        XCTAssertEqual(try connection.mget(["empty", #function]).wait().count, 2)
    }

    func test_set() throws {
        XCTAssertNoThrow(try connection.set(#function, to: "value").wait())
        let val = try connection.get(#function).wait()
        XCTAssertEqual(val, "value")
    }
    
    func test_append() throws {
        let result = "value appended"
        XCTAssertNoThrow(try connection.append("value", to: #function).wait())
        let length = try connection.append(" appended", to: #function).wait()
        XCTAssertEqual(length, result.count)
        let val = try connection.get(#function).wait()
        XCTAssertEqual(val, result)
    }
    
    func test_mset() throws {
        let data = [
            "first": 1,
            "second": 2
        ]
        XCTAssertNoThrow(try connection.mset(data).wait())
        let values = try connection.mget(["first", "second"]).wait().compactMap { $0.string }
        XCTAssertEqual(values.count, 2)
        XCTAssertEqual(values[0], "1")
        XCTAssertEqual(values[1], "2")

        XCTAssertNoThrow(try connection.mset(["first": 10]).wait())
        let val = try connection.get("first").wait()
        XCTAssertEqual(val, "10")
    }

    func test_msetnx() throws {
        let data = [
            "first": 1,
            "second": 2
        ]
        var success = try connection.msetnx(data).wait()
        XCTAssertEqual(success, true)

        success = try connection.msetnx(["first": 10, "second": 20]).wait()
        XCTAssertEqual(success, false)

        let values = try connection.mget(["first", "second"]).wait().compactMap { $0.string }
        XCTAssertEqual(values[0], "1")
        XCTAssertEqual(values[1], "2")
    }

    func test_increment() throws {
        var result = try connection.increment(#function).wait()
        XCTAssertEqual(result, 1)
        result = try connection.increment(#function).wait()
        XCTAssertEqual(result, 2)
    }

    func test_incrementBy() throws {
        var result = try connection.increment(#function, by: 10).wait()
        XCTAssertEqual(result, 10)
        result = try connection.increment(#function, by: -3).wait()
        XCTAssertEqual(result, 7)
        result = try connection.increment(#function, by: 0).wait()
        XCTAssertEqual(result, 7)
    }

    func test_incrementByFloat() throws {
        var float = try connection.increment(#function, by: Float(3.0)).wait()
        XCTAssertEqual(float, 3.0)
        float = try connection.increment(#function, by: Float(-10.135901)).wait()
        XCTAssertEqual(float, -7.135901)

        var double = try connection.increment(#function, by: Double(10.2839)).wait()
        XCTAssertEqual(double, 3.147999)
        double = try connection.increment(#function, by: Double(15.2938)).wait()
        XCTAssertEqual(double, 18.441799)
    }

    func test_decrement() throws {
        var result = try connection.decrement(#function).wait()
        XCTAssertEqual(result, -1)
        result = try connection.decrement(#function).wait()
        XCTAssertEqual(result, -2)
    }

    func test_decrementBy() throws {
        var result = try connection.decrement(#function, by: -10).wait()
        XCTAssertEqual(result, 10)
        result = try connection.decrement(#function, by: 3).wait()
        XCTAssertEqual(result, 7)
        result = try connection.decrement(#function, by: 0).wait()
        XCTAssertEqual(result, 7)
    }

    static var allTests = [
        ("test_get", test_get),
        ("test_mget", test_mget),
        ("test_set", test_set),
        ("test_append", test_append),
        ("test_mset", test_mset),
        ("test_msetnx", test_msetnx),
        ("test_increment", test_increment),
        ("test_incrementBy", test_incrementBy),
        ("test_incrementByFloat", test_incrementByFloat),
        ("test_decrement", test_decrement),
        ("test_decrementBy", test_decrementBy),
    ]
}
