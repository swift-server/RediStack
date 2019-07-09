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
import RedisNIOTestUtils
import XCTest

final class SetCommandsTests: RedisIntegrationTestCase {
    func test_sadd() throws {
        var insertCount = try connection.sadd([1, 2, 3], to: #function).wait()
        XCTAssertEqual(insertCount, 3)
        insertCount = try connection.sadd([3, 4, 5], to: #function).wait()
        XCTAssertEqual(insertCount, 2)
    }

    func test_smembers() throws {
        let first = ["Hello", ","]
        let second = ["World", "!"]

        _ = try connection.sadd(first, to: #function).wait()
        var set = try connection.smembers(of: #function).wait()
        XCTAssertEqual(set.count, 2)

        _ = try connection.sadd(first, to: #function).wait()
        set = try connection.smembers(of: #function).wait()
        XCTAssertEqual(set.count, 2)

        _ = try connection.sadd(second, to: #function).wait()
        set = try connection.smembers(of: #function).wait()
        XCTAssertEqual(set.count, 4)
    }

    func test_sismember() throws {
        _ = try connection.sadd(["Hello"], to: #function).wait()
        XCTAssertTrue(try connection.sismember("Hello", of: #function).wait())

        XCTAssertFalse(try connection.sismember(3, of: #function).wait())
        _ = try connection.sadd([3], to: #function).wait()
        XCTAssertTrue(try connection.sismember(3, of: #function).wait())
    }

    func test_scard() throws {
        XCTAssertEqual(try connection.scard(of: #function).wait(), 0)
        _ = try connection.sadd([1, 2, 3], to: #function).wait()
        XCTAssertEqual(try connection.scard(of: #function).wait(), 3)
    }

    func test_srem() throws {
        var removedCount = try connection.srem([1], from: #function).wait()
        XCTAssertEqual(removedCount, 0)

        _ = try connection.sadd([1], to: #function).wait()
        removedCount = try connection.srem([1], from: #function).wait()
        XCTAssertEqual(removedCount, 1)
    }

    func test_spop() throws {
        var count = try connection.scard(of: #function).wait()
        var result = try connection.spop(from: #function).wait()
        XCTAssertEqual(count, 0)
        XCTAssertEqual(result.count, 0)

        _ = try connection.sadd(["Hello"], to: #function).wait()

        result = try connection.spop(from: #function).wait()
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].string, "Hello")
        count = try connection.scard(of: #function).wait()
        XCTAssertEqual(count, 0)
    }

    func test_srandmember() throws {
        _ = try connection.sadd([1, 2, 3], to: #function).wait()
        XCTAssertEqual(try connection.srandmember(from: #function).wait().count, 1)
        XCTAssertEqual(try connection.srandmember(from: #function, max: 4).wait().count, 3)
        XCTAssertEqual(try connection.srandmember(from: #function, max: -4).wait().count, 4)
    }

    func test_sdiff() throws {
        let key1 = #function
        let key2 = #file
        let key3 = key1 + key2

        _ = try connection.sadd([1, 2, 3], to: key1).wait()
        _ = try connection.sadd([3, 4, 5], to: key2).wait()
        _ = try connection.sadd([2, 4], to: key3).wait()

        let diff1 = try connection.sdiff(of: [key1, key2]).wait()
        XCTAssertEqual(diff1.count, 2)

        let diff2 = try connection.sdiff(of: [key1, key3]).wait()
        XCTAssertEqual(diff2.count, 2)

        let diff3 = try connection.sdiff(of: [key1, key2, key3]).wait()
        XCTAssertEqual(diff3.count, 1)

        let diff4 = try connection.sdiff(of: [key3, key1, key2]).wait()
        XCTAssertEqual(diff4.count, 0)
    }

    func test_sdiffstore() throws {
        let key1 = #function
        let key2 = #file
        let key3 = key1 + key2

        _ = try connection.sadd([1, 2, 3], to: key1).wait()
        _ = try connection.sadd([3, 4, 5], to: key2).wait()

        let diffCount = try connection.sdiffstore(as: key3, sources: [key1, key2]).wait()
        XCTAssertEqual(diffCount, 2)
        let members = try connection.smembers(of: key3).wait()
        XCTAssertEqual(members[0].string, "1")
        XCTAssertEqual(members[1].string, "2")
    }

    func test_sinter() throws {
        let key1 = #function
        let key2 = #file
        let key3 = key1 + key2

        _ = try connection.sadd([1, 2, 3], to: key1).wait()
        _ = try connection.sadd([3, 4, 5], to: key2).wait()
        _ = try connection.sadd([2, 4], to: key3).wait()

        let diff1 = try connection.sinter(of: [key1, key2]).wait()
        XCTAssertEqual(diff1.count, 1)

        let diff2 = try connection.sinter(of: [key1, key3]).wait()
        XCTAssertEqual(diff2.count, 1)

        let diff3 = try connection.sinter(of: [key1, key2, key3]).wait()
        XCTAssertEqual(diff3.count, 0)

        let diff4 = try connection.sinter(of: [key3, key1, key2]).wait()
        XCTAssertEqual(diff4.count, 0)
    }

    func test_sinterstore() throws {
        let key1 = #function
        let key2 = #file
        let key3 = key1 + key2

        _ = try connection.sadd([1, 2, 3], to: key1).wait()
        _ = try connection.sadd([3, 4, 5], to: key2).wait()

        let diffCount = try connection.sinterstore(as: key3, sources: [key1, key2]).wait()
        XCTAssertEqual(diffCount, 1)
        XCTAssertEqual(try connection.smembers(of: key3).wait()[0].string, "3")
    }

    func test_smove() throws {
        _ = try connection.sadd([1, 2, 3], to: #function).wait()
        _ = try connection.sadd([3, 4, 5], to: #file).wait()

        var didMove = try connection.smove(3, from: #function, to: #file).wait()
        XCTAssertTrue(didMove)
        XCTAssertEqual(try connection.scard(of: #function).wait(), 2)
        XCTAssertEqual(try connection.scard(of: #file).wait(), 3)

        didMove = try connection.smove(2, from: #function, to: #file).wait()
        XCTAssertTrue(didMove)
        XCTAssertEqual(try connection.scard(of: #function).wait(), 1)
        XCTAssertEqual(try connection.scard(of: #file).wait(), 4)

        didMove = try connection.smove(6, from: #file, to: #function).wait()
        XCTAssertFalse(didMove)
    }

    func test_sunion() throws {
        let key1 = #function
        let key2 = #file
        let key3 = key1 + key2

        _ = try connection.sadd([1, 2, 3], to: key1).wait()
        _ = try connection.sadd([3, 4, 5], to: key2).wait()
        _ = try connection.sadd([2, 4], to: key3).wait()

        let union1 = try connection.sunion(of: [key1, key2]).wait()
        XCTAssertEqual(union1.count, 5)

        let union2 = try connection.sunion(of: [key2, key3]).wait()
        XCTAssertEqual(union2.count, 4)

        let diff3 = try connection.sunion(of: [key1, key2, key3]).wait()
        XCTAssertEqual(diff3.count, 5)
    }

    func test_sunionstore() throws {
        let key1 = #function
        let key2 = #file
        let key3 = key1 + key2

        _ = try connection.sadd([1, 2, 3], to: key1).wait()
        _ = try connection.sadd([2, 3, 4], to: key2).wait()

        let unionCount = try connection.sunionstore(as: key3, sources: [key1, key2]).wait()
        XCTAssertEqual(unionCount, 4)
        let results = try connection.smembers(of: key3).wait()
        XCTAssertEqual(results[0].string, "1")
        XCTAssertEqual(results[1].string, "2")
        XCTAssertEqual(results[2].string, "3")
        XCTAssertEqual(results[3].string, "4")
    }

    func test_sscan() throws {
        let key = #function
        let dataset = [
            "Copenhagen, Denmark",
            "Roskilde, Denmark",
            "Herning, Denmark",
            "Kolding, Denmark",
            "Taastrup, Denmark",
            "London, England",
            "Bath, England",
            "Birmingham, England",
            "Cambridge, England",
            "Durham, England",
            "Seattle, United States",
            "Austin, United States",
            "New York City, United States",
            "San Francisco, United States",
            "Honolulu, United States"
        ]

        _ = try connection.sadd(dataset, to: key).wait()

        var (cursor, results) = try connection.sscan(key, count: 5).wait()
        XCTAssertGreaterThanOrEqual(cursor, 0)
        XCTAssertGreaterThanOrEqual(results.count, 5)

        (_, results) = try connection.sscan(key, startingFrom: cursor, count: 8).wait()
        XCTAssertGreaterThanOrEqual(results.count, 8)

        (cursor, results) = try connection.sscan(key, matching: "*Denmark").wait()
        XCTAssertGreaterThanOrEqual(cursor, 0)
        XCTAssertGreaterThanOrEqual(results.count, 1)
        XCTAssertLessThanOrEqual(results.count, 5)

        (cursor, results) = try connection.sscan(key, matching: "*ing*").wait()
        XCTAssertGreaterThanOrEqual(cursor, 0)
        XCTAssertGreaterThanOrEqual(results.count, 1)
        XCTAssertLessThanOrEqual(results.count, 3)
    }

    static var allTests = [
        ("test_sadd", test_sadd),
        ("test_smembers", test_smembers),
        ("test_sismember", test_sismember),
        ("test_scard", test_scard),
        ("test_srem", test_srem),
        ("test_spop", test_spop),
        ("test_srandmember", test_srandmember),
        ("test_sdiff", test_sdiff),
        ("test_sdiffstore", test_sdiffstore),
        ("test_sinter", test_sinter),
        ("test_sinterstore", test_sinterstore),
        ("test_smove", test_smove),
        ("test_sunion", test_sunion),
        ("test_sunionstore", test_sunionstore),
        ("test_sscan", test_sscan),
    ]
}
