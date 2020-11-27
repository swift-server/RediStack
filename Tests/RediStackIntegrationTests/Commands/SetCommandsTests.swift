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

final class SetCommandsTests: RediStackIntegrationTestCase {
    func test_sadd() throws {
        var insertCount = try connection.send(.sadd(1, 2, 3, to: #function)).wait()
        XCTAssertEqual(insertCount, 3)
        insertCount = try connection.send(.sadd([3, 4, 5], to: #function)).wait()
        XCTAssertEqual(insertCount, 2)
    }

    func test_smembers() throws {
        let first = ["Hello", ","]
        let second = ["World", "!"]

        _ = try connection.send(.sadd(first, to: #function)).wait()
        var set = try connection.send(.smembers(of: #function)).wait()
        XCTAssertEqual(set.count, 2)

        _ = try connection.send(.sadd(first, to: #function)).wait()
        set = try connection.send(.smembers(of: #function)).wait()
        XCTAssertEqual(set.count, 2)

        _ = try connection.send(.sadd(second, to: #function)).wait()
        set = try connection.send(.smembers(of: #function)).wait()
        XCTAssertEqual(set.count, 4)
    }

    func test_sismember() throws {
        _ = try connection.send(.sadd(["Hello"], to: #function)).wait()
        XCTAssertTrue(try connection.send(.sismember("Hello", of: #function)).wait())

        XCTAssertFalse(try connection.send(.sismember(3, of: #function)).wait())
        _ = try connection.send(.sadd([3], to: #function)).wait()
        XCTAssertTrue(try connection.send(.sismember(3, of: #function)).wait())
    }

    func test_scard() throws {
        XCTAssertEqual(try connection.send(.scard(of: #function)).wait(), 0)
        _ = try connection.send(.sadd([1, 2, 3], to: #function)).wait()
        XCTAssertEqual(try connection.send(.scard(of: #function)).wait(), 3)
    }

    func test_srem() throws {
        var removedCount = try connection.send(.srem(1, from: #function)).wait()
        XCTAssertEqual(removedCount, 0)

        _ = try connection.send(.sadd([1], to: #function)).wait()
        removedCount = try connection.send(.srem([1], from: #function)).wait()
        XCTAssertEqual(removedCount, 1)
    }

    func test_spop() throws {
        var count = try connection.send(.scard(of: #function)).wait()
        var result = try connection.send(.spop(from: #function)).wait()
        XCTAssertEqual(count, 0)
        XCTAssertEqual(result.count, 0)

        _ = try connection.send(.sadd(["Hello"], to: #function)).wait()

        result = try connection.send(.spop(from: #function)).wait()
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].string, "Hello")
        count = try connection.send(.scard(of: #function)).wait()
        XCTAssertEqual(count, 0)
    }

    func test_srandmember() throws {
        _ = try connection.send(.sadd([1, 2, 3], to: #function)).wait()
        XCTAssertEqual(try connection.send(.srandmember(from: #function)).wait().count, 1)
        XCTAssertEqual(try connection.send(.srandmember(from: #function, max: 4)).wait().count, 3)
        XCTAssertEqual(try connection.send(.srandmember(from: #function, max: -4)).wait().count, 4)
    }

    func test_sdiff() throws {
        let key1: RedisKey = #function
        let key2: RedisKey = #file
        let key3 = RedisKey(key1.rawValue + key2.rawValue)

        _ = try connection.send(.sadd([1, 2, 3], to: key1)).wait()
        _ = try connection.send(.sadd([3, 4, 5], to: key2)).wait()
        _ = try connection.send(.sadd([2, 4], to: key3)).wait()

        let diff1 = try connection.send(.sdiff(of: key1, key2)).wait()
        XCTAssertEqual(diff1.count, 2)

        let diff2 = try connection.send(.sdiff(of: key1, key3)).wait()
        XCTAssertEqual(diff2.count, 2)

        let diff3 = try connection.send(.sdiff(of: [key1, key2, key3])).wait()
        XCTAssertEqual(diff3.count, 1)

        let diff4 = try connection.send(.sdiff(of: [key3, key1, key2])).wait()
        XCTAssertEqual(diff4.count, 0)
    }

    func test_sdiffstore() throws {
        let key1: RedisKey = #function
        let key2: RedisKey = #file
        let key3 = RedisKey(key1.rawValue + key2.rawValue)

        _ = try connection.send(.sadd([1, 2, 3], to: key1)).wait()
        _ = try connection.send(.sadd([3, 4, 5], to: key2)).wait()

        let diffCount = try connection.send(.sdiffstore(as: key3, sources: [key1, key2])).wait()
        XCTAssertEqual(diffCount, 2)
        let members = try connection.send(.smembers(of: key3)).wait()
        XCTAssertEqual(members[0].string, "1")
        XCTAssertEqual(members[1].string, "2")
    }

    func test_sinter() throws {
        let key1: RedisKey = #function
        let key2: RedisKey = #file
        let key3 = RedisKey(key1.rawValue + key2.rawValue)

        _ = try connection.send(.sadd([1, 2, 3], to: key1)).wait()
        _ = try connection.send(.sadd([3, 4, 5], to: key2)).wait()
        _ = try connection.send(.sadd([2, 4], to: key3)).wait()

        let diff1 = try connection.send(.sinter(of: key1, key2)).wait()
        XCTAssertEqual(diff1.count, 1)

        let diff2 = try connection.send(.sinter(of: key1, key3)).wait()
        XCTAssertEqual(diff2.count, 1)

        let diff3 = try connection.send(.sinter(of: [key1, key2, key3])).wait()
        XCTAssertEqual(diff3.count, 0)

        let diff4 = try connection.send(.sinter(of: [key3, key1, key2])).wait()
        XCTAssertEqual(diff4.count, 0)
    }

    func test_sinterstore() throws {
        let key1: RedisKey = #function
        let key2: RedisKey = #file
        let key3 = RedisKey(key1.rawValue + key2.rawValue)

        _ = try connection.send(.sadd([1, 2, 3], to: key1)).wait()
        _ = try connection.send(.sadd([3, 4, 5], to: key2)).wait()

        let diffCount = try connection.send(.sinterstore(as: key3, sources: [key1, key2])).wait()
        XCTAssertEqual(diffCount, 1)
        XCTAssertEqual(try connection.send(.smembers(of: key3)).wait()[0].string, "3")
    }

    func test_smove() throws {
        _ = try connection.send(.sadd([1, 2, 3], to: #function)).wait()
        _ = try connection.send(.sadd([3, 4, 5], to: #file)).wait()

        var didMove = try connection.send(.smove(3, from: #function, to: #file)).wait()
        XCTAssertTrue(didMove)
        XCTAssertEqual(try connection.send(.scard(of: #function)).wait(), 2)
        XCTAssertEqual(try connection.send(.scard(of: #file)).wait(), 3)

        didMove = try connection.send(.smove(2, from: #function, to: #file)).wait()
        XCTAssertTrue(didMove)
        XCTAssertEqual(try connection.send(.scard(of: #function)).wait(), 1)
        XCTAssertEqual(try connection.send(.scard(of: #file)).wait(), 4)

        didMove = try connection.send(.smove(6, from: #file, to: #function)).wait()
        XCTAssertFalse(didMove)
    }

    func test_sunion() throws {
        let key1: RedisKey = #function
        let key2: RedisKey = #file
        let key3 = RedisKey(key1.rawValue + key2.rawValue)

        _ = try connection.send(.sadd([1, 2, 3], to: key1)).wait()
        _ = try connection.send(.sadd([3, 4, 5], to: key2)).wait()
        _ = try connection.send(.sadd([2, 4], to: key3)).wait()

        let union1 = try connection.send(.sunion(of: key1, key2)).wait()
        XCTAssertEqual(union1.count, 5)

        let union2 = try connection.send(.sunion(of: [key2, key3])).wait()
        XCTAssertEqual(union2.count, 4)

        let diff3 = try connection.send(.sunion(of: [key1, key2, key3])).wait()
        XCTAssertEqual(diff3.count, 5)
    }

    func test_sunionstore() throws {
        let key1: RedisKey = #function
        let key2: RedisKey = #file
        let key3 = RedisKey(key1.rawValue + key2.rawValue)

        _ = try connection.send(.sadd([1, 2, 3], to: key1)).wait()
        _ = try connection.send(.sadd([2, 3, 4], to: key2)).wait()

        let unionCount = try connection.send(.sunionstore(as: key3, sources: [key1, key2])).wait()
        XCTAssertEqual(unionCount, 4)
        let results = try connection.send(.smembers(of: key3)).wait()
        XCTAssertEqual(results[0].string, "1")
        XCTAssertEqual(results[1].string, "2")
        XCTAssertEqual(results[2].string, "3")
        XCTAssertEqual(results[3].string, "4")
    }
    
    // TODO: #23 -- Rework Scan Unit Test
    // This is extremely flakey, and causes non-deterministic failures because of the assert on key counts
//    func test_sscan() throws {
//        let key: RedisKey = #function
//        let dataset = [
//            "Copenhagen, Denmark",
//            "Roskilde, Denmark",
//            "Herning, Denmark",
//            "Kolding, Denmark",
//            "Taastrup, Denmark",
//            "London, England",
//            "Bath, England",
//            "Birmingham, England",
//            "Cambridge, England",
//            "Durham, England",
//            "Seattle, United States",
//            "Austin, United States",
//            "New York City, United States",
//            "San Francisco, United States",
//            "Honolulu, United States"
//        ]
//
//        _ = try connection.sadd(dataset, to: key).wait()
//
//        var (cursor, results) = try connection.sscan(key, count: 5).wait()
//        XCTAssertGreaterThanOrEqual(cursor, 0)
//        XCTAssertGreaterThanOrEqual(results.count, 5)
//
//        (_, results) = try connection.sscan(key, startingFrom: cursor, count: 8).wait()
//        XCTAssertGreaterThanOrEqual(results.count, 8)
//
//        (cursor, results) = try connection.sscan(key, matching: "*Denmark").wait()
//        XCTAssertGreaterThanOrEqual(cursor, 0)
//        XCTAssertGreaterThanOrEqual(results.count, 1)
//        XCTAssertLessThanOrEqual(results.count, 5)
//
//        (cursor, results) = try connection.sscan(key, matching: "*ing*").wait()
//        XCTAssertGreaterThanOrEqual(cursor, 0)
//        XCTAssertGreaterThanOrEqual(results.count, 1)
//        XCTAssertLessThanOrEqual(results.count, 3)
//    }
}
