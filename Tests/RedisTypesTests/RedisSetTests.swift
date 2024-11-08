//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2020 Apple Inc. and the RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import RediStackTestUtils
import RedisTypes
import XCTest

@testable import RediStack

final class RedisSetTests: RedisTypesIntegrationTestCase {
    func testInit() {
        let firstSet = RedisSet<Int>(identifier: #function, client: self.connection)
        XCTAssertEqual(firstSet.identifier, #function)
    }

    func testInsert() {
        let set = self.connection.makeSet(key: #function, type: Int.self)
        XCTAssertNoThrow(try set.insert(3).wait())
        XCTAssertNoThrow(try set.insert(contentsOf: [1, 2, 3]).wait())

        let insertFuture = set.insert(contentsOf: [3, 4])
        XCTAssertNoThrow(try insertFuture.wait())
        XCTAssertEqual(try insertFuture.wait(), 1)
    }

    func testCount() throws {
        let set = self.connection.makeSet(key: #function, type: String.self)
        XCTAssertEqual(try set.count.wait(), 0)

        let string = "Hello, Redis Types!"
        XCTAssertNoThrow(try set.insert(string).wait())
        XCTAssertEqual(try set.count.wait(), 1)
        XCTAssertEqual(try set.allElements.wait(), [string])
    }

    func testMove() throws {
        let firstSet = self.connection.makeSet(key: .init("\(#function)_1"), type: Int.self)
        let secondSet = self.connection.makeSet(key: .init("\(#function)_2"), type: Int.self)

        _ = try firstSet.insert(3).wait()
        _ = try secondSet.insert(4).wait()

        XCTAssertTrue(try firstSet.move(3, to: secondSet).wait())
        XCTAssertTrue(try firstSet.isEmpty.wait())
        XCTAssertEqual(try secondSet.count.wait(), 2)

        XCTAssertFalse(try firstSet.contains(3).wait())
        XCTAssertFalse(try firstSet.move(3, to: secondSet).wait())
    }

    func testRemove() throws {
        let set = self.connection.makeSet(key: #function, type: Int.self)

        _ = try set.insert(contentsOf: [1, 2, 3]).wait()

        XCTAssertFalse(try set.remove(4).wait())
        XCTAssertTrue(try set.remove(3).wait())

        XCTAssertNoThrow(try set.remove([]).wait())

        let removed = try set.remove([1, 2]).wait()
        XCTAssertEqual(removed, 2)
    }

    func testRemoveAll() throws {
        let set = self.connection.makeSet(key: #function, type: Int.self)

        XCTAssertNoThrow(try set.insert(contentsOf: []).wait())

        let inserted = try set.insert(contentsOf: [1, 2, 3]).wait()
        XCTAssertEqual(inserted, 3)

        XCTAssertTrue(try set.removeAll().wait())
        XCTAssertEqual(try set.count.wait(), 0)
    }

    func testPopRandomElement() throws {
        let set = self.connection.makeSet(key: #function, type: String.self)

        XCTAssertNil(try set.popRandomElement().wait())

        _ = try set.insert(contentsOf: ["Hello", ",", "World", "!"]).wait()

        XCTAssertNotNil(try set.popRandomElement().wait())
        XCTAssertEqual(try set.count.wait(), 3)
    }

    func testPopRandomElements() throws {
        let set = self.connection.makeSet(key: #function, type: Int.self)

        XCTAssertNoThrow(try set.insert(contentsOf: [1, 2, 3]).wait())

        XCTAssertThrowsError(try set.popRandomElements(max: -1).wait())

        var elements = try set.popRandomElements(max: 0).wait()
        XCTAssertEqual(elements.count, 0)

        elements = try set.popRandomElements(max: 2).wait()
        XCTAssertEqual(elements.count, 2)
        XCTAssertEqual(try set.count.wait(), 1)

        elements = try set.popRandomElements(max: 2).wait()
        XCTAssertEqual(elements.count, 1)
        XCTAssertEqual(try set.count.wait(), 0)
    }

    func testRandomElement() throws {
        let set = self.connection.makeSet(key: #function, type: String.self)

        XCTAssertNil(try set.randomElement().wait())

        let values = ["RediStack", "SSWG", "Swift"]

        XCTAssertNoThrow(try set.insert(contentsOf: values).wait())

        let randomElement = try set.randomElement().wait()
        XCTAssertNotNil(randomElement)
        XCTAssertTrue(values.contains(randomElement ?? "nope"))
        XCTAssertEqual(try set.count.wait(), 3)
    }

    func testRandomElements() throws {
        let set = self.connection.makeSet(key: #function, type: Int.self)

        _ = try set.insert(contentsOf: [1, 2, 3]).wait()

        var elements = try set.randomElements(max: 4).wait()
        XCTAssertEqual(elements.count, 3)

        elements = try set.randomElements(max: 4, allowDuplicates: true).wait()
        XCTAssertEqual(elements.count, 4)
    }
}
