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

final class ListCommandsTests: RediStackIntegrationTestCase {
    func test_llen() throws {
        var length = try connection.llen(of: #function).wait()
        XCTAssertEqual(length, 0)
        _ = try connection.lpush([30], into: #function).wait()
        length = try connection.llen(of: #function).wait()
        XCTAssertEqual(length, 1)
    }

    func test_lindex() throws {
        var element = try connection.lindex(0, from: #function).wait()
        XCTAssertTrue(element.isNull)

        _ = try connection.lpush([10], into: #function).wait()

        element = try connection.lindex(0, from: #function).wait()
        XCTAssertFalse(element.isNull)
        XCTAssertEqual(Int(fromRESP: element), 10)
    }

    func test_lset() throws {
        XCTAssertThrowsError(try connection.lset(index: 0, to: 30, in: #function).wait())
        _ = try connection.lpush([10], into: #function).wait()
        XCTAssertNoThrow(try connection.lset(index: 0, to: 30, in: #function).wait())
        let element = try connection.lindex(0, from: #function).wait()
        XCTAssertEqual(Int(fromRESP: element), 30)
    }

    func test_lrem() throws {
        _ = try connection.lpush([10, 10, 20, 30, 10], into: #function).wait()
        var count = try connection.lrem(10, from: #function, count: 2).wait()
        XCTAssertEqual(count, 2)
        count = try connection.lrem(10, from: #function, count: 2).wait()
        XCTAssertEqual(count, 1)
    }

    func test_lrange() throws {
        var elements = try connection.lrange(from: #function, indices: 0...10).wait()
        XCTAssertEqual(elements.count, 0)

        _ = try connection.lpush([5, 4, 3, 2, 1], into: #function).wait()

        elements = try connection.lrange(from: #function, throughIndex: 4).wait()
        XCTAssertEqual(elements.count, 5)
        XCTAssertEqual(Int(fromRESP: elements[0]), 1)
        XCTAssertEqual(Int(fromRESP: elements[4]), 5)
        
        elements = try connection.lrange(from: #function, fromIndex: 1).wait()
        XCTAssertEqual(elements.count, 4)
        elements = try connection.lrange(from: #function, fromIndex: -3).wait()
        XCTAssertEqual(elements.count, 3)

        elements = try connection.lrange(from: #function, firstIndex: 2, lastIndex: 0).wait()
        XCTAssertEqual(elements.count, 0)

        elements = try connection.lrange(from: #function, indices: 4...5).wait()
        XCTAssertEqual(elements.count, 1)

        elements = try connection.lrange(from: #function, upToIndex: -3).wait()
        XCTAssertEqual(elements.count, 2)
    }

    func test_rpoplpush() throws {
        _ = try connection.lpush([10], into: "first").wait()
        _ = try connection.lpush([30], into: "second").wait()

        var element = try connection.rpoplpush(from: "first", to: "second").wait()
        XCTAssertEqual(Int(fromRESP: element), 10)
        XCTAssertEqual(try connection.llen(of: "first").wait(), 0)
        XCTAssertEqual(try connection.llen(of: "second").wait(), 2)

        element = try connection.rpoplpush(from: "second", to: "first").wait()
        XCTAssertEqual(Int(fromRESP: element), 30)
        XCTAssertEqual(try connection.llen(of: "second").wait(), 1)
    }

    func test_brpoplpush() throws {
        _ = try connection.lpush([10], into: "first").wait()

        let element = try connection.brpoplpush(from: "first", to: "second").wait()
        XCTAssertEqual(Int(fromRESP: element), 10)

        let blockingConnection = try self.makeNewConnection()
        let expectation = XCTestExpectation(description: "brpoplpush should never return")
        _ = blockingConnection.bzpopmin(from: #function)
            .always { _ in
                expectation.fulfill()
                blockingConnection.close()
            }

        let result = XCTWaiter.wait(for: [expectation], timeout: 1)
        XCTAssertEqual(result, .timedOut)
    }

    func test_linsert() throws {
        _ = try connection.lpush([10], into: #function).wait()

        _ = try connection.linsert(20, into: #function, after: 10).wait()
        var elements = try connection.lrange(from: #function, throughIndex: 1)
            .map { response in response.compactMap { Int(fromRESP: $0) } }
            .wait()
        XCTAssertEqual(elements, [10, 20])

        _ = try connection.linsert(30, into: #function, before: 10).wait()
        elements = try connection.lrange(from: #function, throughIndex: 2)
            .map { response in response.compactMap { Int(fromRESP: $0) } }
            .wait()
        XCTAssertEqual(elements, [30, 10, 20])
    }

    func test_lpop() throws {
        var element = try connection.lpop(from: #function).wait()
        XCTAssertTrue(element.isNull)

        _ = try connection.lpush([10, 20, 30], into: #function).wait()

        element = try connection.lpop(from: #function).wait()
        XCTAssertFalse(element.isNull)
        XCTAssertEqual(Int(fromRESP: element), 30)
    }

    func test_blpop() throws {
        let nilPop = try connection.blpop(from: #function, timeout: .seconds(1)).wait()
        XCTAssertEqual(nilPop, .null)

        _ = try connection.lpush([10, 20, 30], into: "first").wait()
        let pop1 = try connection.blpop(from: "first").wait()
        XCTAssertEqual(Int(fromRESP: pop1), 30)

        let pop2 = try connection.blpop(from: "fake", "first").wait()
        XCTAssertEqual(pop2?.0, "first")

        let blockingConnection = try self.makeNewConnection()
        let expectation = XCTestExpectation(description: "blpop should never return")
        _ = blockingConnection.bzpopmin(from: #function)
            .always { _ in
                expectation.fulfill()
                blockingConnection.close()
            }

        let result = XCTWaiter.wait(for: [expectation], timeout: 1)
        XCTAssertEqual(result, .timedOut)
    }

    func test_lpush() throws {
        _ = try connection.rpush([10, 20, 30], into: #function).wait()

        let size = try connection.lpush(100, into: #function).wait()
        let element = try connection.lindex(0, from: #function).wait()
        XCTAssertEqual(size, 4)
        XCTAssertEqual(Int(fromRESP: element), 100)
    }

    func test_lpushx() throws {
        var size = try connection.lpushx(10, into: #function).wait()
        XCTAssertEqual(size, 0)

        _ = try connection.lpush([10], into: #function).wait()

        size = try connection.lpushx(30, into: #function).wait()
        XCTAssertEqual(size, 2)
        let element = try connection.rpop(from: #function)
            .map { return Int(fromRESP: $0) }
            .wait()
        XCTAssertEqual(element, 10)
    }

    func test_rpop() throws {
        _ = try connection.lpush([10, 20, 30], into: #function).wait()

        let element = try connection.rpop(from: #function).wait()
        XCTAssertNotNil(element)
        XCTAssertEqual(Int(fromRESP: element), 10)

        _ = try connection.delete([#function]).wait()

        let result = try connection.rpop(from: #function).wait()
        XCTAssertTrue(result.isNull)
    }

    func test_brpop() throws {
        let nilPop = try connection.brpop(from: #function, timeout: .seconds(1)).wait()
        XCTAssertEqual(nilPop, .null)

        _ = try connection.lpush([10, 20, 30], into: "first").wait()
        let pop1 = try connection.brpop(from: "first").wait()
        XCTAssertEqual(Int(fromRESP: pop1), 10)

        let pop2 = try connection.brpop(from: "fake", "first").wait()
        XCTAssertEqual(pop2?.0, "first")

        let blockingConnection = try self.makeNewConnection()
        let expectation = XCTestExpectation(description: "brpop should never return")
        _ = blockingConnection.bzpopmin(from: #function)
            .always { _ in
                expectation.fulfill()
                blockingConnection.close()
            }

        let result = XCTWaiter.wait(for: [expectation], timeout: 1)
        XCTAssertEqual(result, .timedOut)
    }

    func test_rpush() throws {
        _ = try connection.lpush([10, 20, 30], into: #function).wait()

        let size = try connection.rpush(100, into: #function).wait()
        let element = try connection.lindex(3, from: #function).wait()
        XCTAssertEqual(size, 4)
        XCTAssertEqual(Int(fromRESP: element), 100)
    }

    func test_rpushx() throws {
        var size = try connection.rpushx(10, into: #function).wait()
        XCTAssertEqual(size, 0)

        _ = try connection.rpush([10], into: #function).wait()

        size = try connection.rpushx(30, into: #function).wait()
        XCTAssertEqual(size, 2)
        let element = try connection.lpop(from: #function)
            .map { return Int(fromRESP: $0) }
            .wait()
        XCTAssertEqual(element, 10)
    }
    
    func test_ltrim() throws {
        let setup = {
            _ = try self.connection.delete(#function).wait()
            _ = try self.connection.lpush([5, 4, 3, 2, 1], into: #function).wait()
        }
        let getElements = { return try self.connection.lrange(from: #function, fromIndex: 0).wait() }
        
        try setup()
        
        XCTAssertNoThrow(try connection.ltrim(#function, before: 1, after: 3).wait())
        XCTAssertNoThrow(try connection.ltrim(#function, keepingIndices: 0...1).wait())
        var elements = try getElements()
        XCTAssertEqual(elements.count, 2)
        
        try setup()
        
        XCTAssertNoThrow(try connection.ltrim(#function, keepingIndices: (-3)...).wait())
        elements = try getElements()
        XCTAssertEqual(elements.count, 3)
        
        try setup()
        
        XCTAssertNoThrow(try connection.ltrim(#function, keepingIndices: ...(-4)).wait())
        elements = try getElements()
        XCTAssertEqual(elements.count, 2)
        
        try setup()
        XCTAssertNoThrow(try connection.ltrim(#function, keepingIndices: ..<(-2)).wait())
        elements = try getElements()
        XCTAssertEqual(elements.count, 3)
    }
}
