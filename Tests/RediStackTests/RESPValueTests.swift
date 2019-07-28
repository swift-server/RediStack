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

import RediStack
import XCTest

final class RESPValueTests: XCTestCase {
    func test_equatable() {
        let redisError = RedisError(reason: "testing")
        
        let null = RESPValue.null
        let error = RESPValue.error(redisError)
        let array = RESPValue.array([.null, error])
        let integer = RESPValue.integer(3)
        let simpleString = RESPValue.simpleString("OK".byteBuffer)
        let bulkString = RESPValue.bulkString(nil)
        
        XCTAssertEqual(null, .null)
        XCTAssertNotEqual(null, error)
        XCTAssertNotEqual(null, array)
        XCTAssertNotEqual(null, integer)
        XCTAssertNotEqual(null, simpleString)
        XCTAssertNotEqual(null, bulkString)
        
        XCTAssertEqual(error, .error(redisError))
        XCTAssertNotEqual(error, .error(RedisError(reason: "failure")))
        XCTAssertNotEqual(error, integer)
        XCTAssertNotEqual(error, simpleString)
        XCTAssertNotEqual(error, bulkString)
        XCTAssertNotEqual(error, array)
        
        XCTAssertEqual(array, .array([.null, error]))
        XCTAssertNotEqual(array, .array([integer]))
        XCTAssertNotEqual(array, integer)
        XCTAssertNotEqual(array, simpleString)
        XCTAssertNotEqual(array, bulkString)
        
        XCTAssertEqual(integer, .integer(3))
        XCTAssertNotEqual(integer, .integer(Int.max))
        XCTAssertNotEqual(integer, simpleString)
        XCTAssertNotEqual(integer, bulkString)
        
        XCTAssertEqual(simpleString, .simpleString("OK".byteBuffer))
        XCTAssertNotEqual(simpleString, .simpleString(#function.byteBuffer))
        XCTAssertNotEqual(simpleString, bulkString)
        
        XCTAssertEqual(bulkString, .bulkString(nil))
        XCTAssertNotEqual(bulkString, .bulkString("OK".byteBuffer))
    }
}
