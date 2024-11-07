//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2023 RediStack project authors
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

final class RedisHashSlotTests: XCTestCase {
    func testEdgeValues() {
        XCTAssertEqual(RedisHashSlot.min.rawValue, 0)
        XCTAssertEqual(RedisHashSlot.max.rawValue, UInt16(pow(2.0, 14.0)) - 1)
        XCTAssertEqual(RedisHashSlot.unknown.rawValue, UInt16.max)
    }

    func testExpressibleByIntegerLiteral() {
        let value: RedisHashSlot = 123
        XCTAssertEqual(value.rawValue, 123)
    }

    func testStridable() {
        let value: RedisHashSlot = 123
        XCTAssertEqual(value.advanced(by: 12), 135)
    }

    func testComparable() {
        let value: RedisHashSlot = 123
        XCTAssertGreaterThan(value.advanced(by: 1), value)
        XCTAssertLessThan(value.advanced(by: -1), value)
    }

    func testCRC16() {
        XCTAssertEqual(crc16("123456789".utf8), 0x31C3)

        // test cases generated here: https://crccalc.com
        XCTAssertEqual(crc16("Peter".utf8), 0x5E67)
        XCTAssertEqual(crc16("Fabian".utf8), 0x504F)
        XCTAssertEqual(crc16("Inverness".utf8), 0x7619)
        XCTAssertEqual(crc16("Redis is awesome".utf8), 0x345C)
        XCTAssertEqual(crc16([0xFF, 0xFF, 0x00, 0x00]), 0x84C0)
        XCTAssertEqual(crc16([0x00, 0x00]), 0x0000)
    }

    func testHashTagComputation() {
        XCTAssert(
            RedisHashSlot.hashTag(forKey: "{user1000}.following").elementsEqual(
                RedisHashSlot.hashTag(forKey: "{user1000}.followers")
            )
        )
        XCTAssert(RedisHashSlot.hashTag(forKey: "{user1000}.following").elementsEqual("user1000".utf8))
        XCTAssert(RedisHashSlot.hashTag(forKey: "{user1000}.followers").elementsEqual("user1000".utf8))

        XCTAssert(RedisHashSlot.hashTag(forKey: "foo{}{bar}").elementsEqual("foo{}{bar}".utf8))
        XCTAssert(RedisHashSlot.hashTag(forKey: "foo{{bar}}zap").elementsEqual("{bar".utf8))
        XCTAssert(RedisHashSlot.hashTag(forKey: "foo{bar}{zap}").elementsEqual("bar".utf8))
        XCTAssert(RedisHashSlot.hashTag(forKey: "{}foo{bar}{zap}").elementsEqual("{}foo{bar}{zap}".utf8))
        XCTAssert(RedisHashSlot.hashTag(forKey: "foo").elementsEqual("foo".utf8))
        XCTAssert(RedisHashSlot.hashTag(forKey: "foo}").elementsEqual("foo}".utf8))
        XCTAssert(RedisHashSlot.hashTag(forKey: "{foo}").elementsEqual("foo".utf8))
        XCTAssert(RedisHashSlot.hashTag(forKey: "bar{foo}").elementsEqual("foo".utf8))
        XCTAssert(RedisHashSlot.hashTag(forKey: "bar{}").elementsEqual("bar{}".utf8))
        XCTAssert(RedisHashSlot.hashTag(forKey: "{}").elementsEqual("{}".utf8))
        XCTAssert(RedisHashSlot.hashTag(forKey: "{}bar").elementsEqual("{}bar".utf8))
    }

    func testDescription() {
        XCTAssertEqual(String(describing: RedisHashSlot.min), "0")
        XCTAssertEqual(String(describing: RedisHashSlot.max), "16383")
        XCTAssertEqual(String(describing: RedisHashSlot.unknown), "unknown")
        XCTAssertEqual(String(describing: RedisHashSlot(rawValue: 3000)!), "3000")
        XCTAssertEqual(String(describing: RedisHashSlot(rawValue: 20)!), "20")
    }
}
