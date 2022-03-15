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

import NIO
@testable import RediStack
import RediStackTestUtils
import XCTest

final class SortedSetCommandsTests: RediStackIntegrationTestCase {
    private static let testKey: RedisKey = "SortedSetCommandsTests"

    private var key: RedisKey { return SortedSetCommandsTests.testKey }

    override func setUp() {
        super.setUp()
        do {
            var dataset: [(Int, Double)] = []
            for index in 1...10 {
                dataset.append((index, Double(index)))
            }

            _ = try connection.send(.zadd(dataset, to: SortedSetCommandsTests.testKey)).wait()
        } catch {
            XCTFail("Failed to create RedisConnection! \(error)")
        }
    }

    func test_zadd() throws {
        _ = try connection.send(.flushall).wait()

        var count = try connection.send(.zadd([(30, 2)], to: #function)).wait()
        XCTAssertEqual(count, 1)
        count = try connection.send(.zadd([(30, 5)], to: #function)).wait()
        XCTAssertEqual(count, 0)
        count = try connection.send(.zadd((30, 6), (31, 0), (32, 1), to: #function, inserting: .onlyNewElements)).wait()
        XCTAssertEqual(count, 2)
        count = try connection.send(.zadd(
            [(32, 2), (33, 3)],
            to: #function,
            inserting: .onlyExistingElements,
            returning: .changedElementsCount
        )).wait()
        XCTAssertEqual(count, 1)

        var success = try connection.send(.zadd((30, 7), to: #function, returning: .changedElementsCount)).wait()
        XCTAssertTrue(success)
        success = try connection.send(.zadd((30, 8), to: #function, inserting: .onlyNewElements)).wait()
        XCTAssertFalse(success)
    }

    func test_zcard() throws {
        var count = try connection.send(.zcard(of: key)).wait()
        XCTAssertEqual(count, 10)

        _ = try connection.send(.zadd(("foo", 0), to: key)).wait()

        count = try connection.send(.zcard(of: key)).wait()
        XCTAssertEqual(count, 11)
    }

    func test_zscore() throws {
        _ = try connection.send(.flushall).wait()

        var score = try connection.send(.zscore(of: 30, in: #function)).wait()
        XCTAssertEqual(score, nil)

        _ = try connection.send(.zadd((30, 1), to: #function)).wait()

        score = try connection.send(.zscore(of: 30, in: #function)).wait()
        XCTAssertEqual(score, 1)

        _ = try connection.send(.zincrby(30, in: #function, by: 10)).wait()

        score = try connection.send(.zscore(of: 30, in: #function)).wait()
        XCTAssertEqual(score, 11)
    }
    
    // TODO: #23 -- Rework Scan Unit Test
    // This is extremely flakey, and causes non-deterministic failures because of the assert on key counts
//    func test_zscan() throws {
//        var (cursor, results) = try connection.zscan(key, count: 5).wait()
//        XCTAssertGreaterThanOrEqual(cursor, 0)
//        XCTAssertGreaterThanOrEqual(results.count, 5)
//
//        (_, results) = try connection.zscan(key, startingFrom: cursor, count: 8).wait()
//        XCTAssertGreaterThanOrEqual(results.count, 8)
//
//        (cursor, results) = try connection.zscan(key, matching: "1*").wait()
//        XCTAssertEqual(cursor, 0)
//        XCTAssertEqual(results.count, 2)
//        XCTAssertEqual(results[0].1, 1)
//
//        (cursor, results) = try connection.zscan(key, matching: "*0").wait()
//        XCTAssertEqual(cursor, 0)
//        XCTAssertEqual(results.count, 1)
//        XCTAssertEqual(results[0].1, 10)
//    }

    func test_zrank() throws {
        let futures = [
            connection.send(.zrank(of: 1, in: key)),
            connection.send(.zrank(of: 2, in: key)),
            connection.send(.zrank(of: 3, in: key)),
        ]
        let scores = try EventLoopFuture<Int?>.whenAllSucceed(futures, on: connection.eventLoop).wait()
        XCTAssertEqual(scores, [0, 1, 2])
    }

    func test_zrevrank() throws {
        let futures = [
            connection.send(.zrevrank(of: 1, in: key)),
            connection.send(.zrevrank(of: 2, in: key)),
            connection.send(.zrevrank(of: 3, in: key)),
        ]
        let scores = try EventLoopFuture<Int?>.whenAllSucceed(futures, on: connection.eventLoop).wait()
        XCTAssertEqual(scores, [9, 8, 7])
    }

    func test_zcount() throws {
        var count = try connection.send(.zcount(of: key, withScores: 1...3)).wait()
        XCTAssertEqual(count, 3)
        
        count = try connection.send(.zcount(of: key, withScoresBetween: (.exclusive(1), .exclusive(3)))).wait()
        XCTAssertEqual(count, 1)
        
        count = try connection.send(.zcount(of: key, withScores: 3..<8)).wait()
        XCTAssertEqual(count, 5)
        
        count = try connection.send(.zcount(of: key, withMinimumScoreOf: .exclusive(7))).wait()
        XCTAssertEqual(count, 3)
        
        count = try connection.send(.zcount(of: key, withMaximumScoreOf: 10)).wait()
        XCTAssertEqual(count, 10)
        
        count = try connection.send(.zcount(of: key, withScoresBetween: (3, 0))).wait()
        XCTAssertEqual(count, 0)
    }

    func test_zlexcount() throws {
        for i in 1...10 {
            _ = try connection.send(.zadd((i, 1), to: #function)).wait()
        }
        
        var count = try connection.send(.zlexcount(of: #function, withValuesBetween: (.inclusive(1), .inclusive(3)))).wait()
        XCTAssertEqual(count, 4)
        
        count = try connection.send(.zlexcount(of: #function, withValuesBetween: (.exclusive(1), .exclusive(3)))).wait()
        XCTAssertEqual(count, 2)
        
        count = try connection.send(.zlexcount(of: #function, withMinimumValueOf: .inclusive(2))).wait()
        XCTAssertEqual(count, 8)
        
        count = try connection.send(.zlexcount(of: #function, withMaximumValueOf: .exclusive(3))).wait()
        XCTAssertEqual(count, 3)
    }

    func test_zpopmin() throws {
        let min = try connection.send(.zpopmin(from: key)).wait()
        XCTAssertEqual(min?.1, 1)

        _ = try connection.send(.zpopmin(from: key, max: 7)).wait()

        let results = try connection.send(.zpopmin(from: key, max: 3)).wait()
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].1, 9)
        XCTAssertEqual(results[1].1, 10)
    }

    func test_bzpopmin() throws {
        let nilMin = try connection.send(.bzpopmin(from: #function, timeout: .seconds(1))).wait()
        XCTAssertNil(nilMin)

        let min1 = try connection.send(.bzpopmin(from: key)).wait()
        XCTAssertEqual(min1?.0, 1)
        let min2 = try connection.send(.bzpopmin(from: [#function, key])).wait()
        XCTAssertEqual(min2?.0, key.rawValue)
        XCTAssertEqual(min2?.1, 2)

        let blockingConnection = try self.makeNewConnection()
        let expectation = XCTestExpectation(description: "bzpopmin should never return")
        _ = blockingConnection.send(.bzpopmin(from: #function))
            .always { _ in
                expectation.fulfill()
                blockingConnection.close()
            }

        let result = XCTWaiter.wait(for: [expectation], timeout: 1)
        XCTAssertEqual(result, .timedOut)
    }

    func test_zpopmax() throws {
        let min = try connection.send(.zpopmax(from: key)).wait()
        XCTAssertEqual(min?.1, 10)

        _ = try connection.send(.zpopmax(from: key, max: 7)).wait()

        let results = try connection.send(.zpopmax(from: key, max: 3)).wait()
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].1, 2)
        XCTAssertEqual(results[1].1, 1)
    }

    func test_bzpopmax() throws {
        let nilMax = try connection.send(.bzpopmax(from: #function, timeout: .seconds(1))).wait()
        XCTAssertNil(nilMax)

        let max1 = try connection.send(.bzpopmax(from: key)).wait()
        XCTAssertEqual(max1?.0, 10)
        let max2 = try connection.send(.bzpopmax(from: [#function, key])).wait()
        XCTAssertEqual(max2?.0, key.rawValue)
        XCTAssertEqual(max2?.1, 9)

        let blockingConnection = try self.makeNewConnection()
        let expectation = XCTestExpectation(description: "bzpopmax should never return")
        _ = blockingConnection.send(.bzpopmax(from: #function))
            .always { _ in
                expectation.fulfill()
                blockingConnection.close()
            }

        let result = XCTWaiter.wait(for: [expectation], timeout: 1)
        XCTAssertEqual(result, .timedOut)
    }

    func test_zincrby() throws {
        var score = try connection.send(.zincrby(1, in: key, by: 3_00_1398.328923)).wait()
        XCTAssertEqual(score, 3_001_399.328923)

        score = try connection.send(.zincrby(1, in: key, by: -201_309.1397318)).wait()
        XCTAssertEqual(score, 2_800_090.1891912)

        score = try connection.send(.zincrby(1, in: key, by: 20)).wait()
        XCTAssertEqual(score, 2_800_110.1891912)
    }

    func test_zunionstore() throws {
        let testKey = RedisKey(#function + #file)
        
        _ = try connection.send(.zadd([(1, 1), (2, 2)], to: #function)).wait()
        _ = try connection.send(.zadd([(3, 3), (4, 4)], to: #file)).wait()

        let unionCount = try connection.send(.zunionstore(
            as: testKey,
            sources: [key, #function, #file],
            weights: [3, 2, 1],
            aggregateMethod: .max
        )).wait()
        XCTAssertEqual(unionCount, 10)
        let rank = try connection.send(.zrank(of: 10, in: testKey)).wait()
        XCTAssertEqual(rank, 9)
        let score = try connection.send(.zscore(of: 10, in: testKey)).wait()
        XCTAssertEqual(score, 30)
    }

    func test_zinterstore() throws {
        _ = try connection.send(.zadd([(3, 3), (10, 10), (11, 11)], to: #function)).wait()

        let unionCount = try connection.send(.zinterstore(
            as: #file,
            sources: [key, #function],
            weights: [3, 2],
            aggregateMethod: .min
        )).wait()
        XCTAssertEqual(unionCount, 2)
        let rank = try connection.send(.zrank(of: 10, in: #file)).wait()
        XCTAssertEqual(rank, 1)
        let score = try connection.send(.zscore(of: 10, in: #file)).wait()
        XCTAssertEqual(score, 20.0)
    }

    func test_zrange() throws {
        var elements = try connection.send(.zrange(from: key, indices: 1...3, returning: .valuesOnly)).wait()
        XCTAssertEqual(elements.count, 3)
        
        elements = try connection.send(.zrange(from: key, indices: 3..<9, returning: .valuesOnly)).wait()
        XCTAssertEqual(elements.count, 6)
        
        elements = try connection.send(.zrange(from: key, upToIndex: 4, returning: .valuesOnly)).wait()
        XCTAssertEqual(elements.count, 4)
        
        elements = try connection.send(.zrange(from: key, throughIndex: 4, returning: .valuesOnly)).wait()
        XCTAssertEqual(elements.count, 5)
        
        elements = try connection.send(.zrange(from: key, fromIndex: 7, returning: .valuesOnly)).wait()
        XCTAssertEqual(elements.count, 3)
        
        let elementsAndScores = try connection.send(.zrange(from: key, firstIndex: 1, lastIndex: 3, returning: .valuesAndScores)).wait()
        XCTAssertEqual(elementsAndScores.count, 3)

        let values = elementsAndScores.map { Int(fromRESP: $0.0) }
        XCTAssertEqual(values[0], 2)
        XCTAssertEqual(values[1], 3)
        XCTAssertEqual(values[2], 4)
    }

    func test_zrevrange() throws {
        var elements = try connection.send(.zrevrange(from: key, indices: 1...3, returning: .valuesOnly)).wait()
        XCTAssertEqual(elements.count, 3)

        elements = try connection.send(.zrevrange(from: key, indices: 3..<9, returning: .valuesOnly)).wait()
        XCTAssertEqual(elements.count, 6)
        
        elements = try connection.send(.zrevrange(from: key, upToIndex: 4, returning: .valuesOnly)).wait()
        XCTAssertEqual(elements.count, 4)
        
        elements = try connection.send(.zrevrange(from: key, throughIndex: 4, returning: .valuesOnly)).wait()
        XCTAssertEqual(elements.count, 5)
        
        elements = try connection.send(.zrevrange(from: key, fromIndex: 7, returning: .valuesOnly)).wait()
        XCTAssertEqual(elements.count, 3)
        
        let elementsAndScores = try connection.send(.zrevrange(from: key, firstIndex: 1, lastIndex: 3, returning: .valuesAndScores)).wait()
        XCTAssertEqual(elementsAndScores.count, 3)

        let values = elementsAndScores.map { value, _ in Int(fromRESP: value) }
        XCTAssertEqual(values[0], 9)
        XCTAssertEqual(values[1], 8)
        XCTAssertEqual(values[2], 7)
    }

    func test_zrangebyscore() throws {
        var elements = try connection.send(.zrangebyscore(from: key, withScoresBetween: (.exclusive(1), 3), returning: .valuesOnly)).wait()
        XCTAssertEqual(elements.count, 2)
        
        elements = try connection.send(.zrangebyscore(from: key, withScores: 7..<10, limitBy: (offset: 2, count: 3), returning: .valuesOnly)).wait()
        XCTAssertEqual(elements.count, 1)
        
        elements = try connection.send(.zrangebyscore(from: key, withMinimumScoreOf: .exclusive(5), returning: .valuesOnly)).wait()
        XCTAssertEqual(elements.count, 5)
        
        elements = try connection.send(.zrangebyscore(from: key, withMaximumScoreOf: 5, returning: .valuesOnly)).wait()
        XCTAssertEqual(elements.count, 5)
        
        let elementsAndScores = try connection.send(.zrangebyscore(from: key, withScores: 1...3, returning: .valuesAndScores)).wait()
        XCTAssertEqual(elementsAndScores.count, 3)

        let values = elementsAndScores.map { value, _ in Double(fromRESP: value) }
        XCTAssertEqual(values[0], 1.0)
        XCTAssertEqual(values[1], 2.0)
        XCTAssertEqual(values[2], 3.0)
    }

    func test_zrevrangebyscore() throws {
        var elements = try connection.send(.zrevrangebyscore(from: key, withScoresBetween: (.exclusive(1), 3), returning: .valuesOnly)).wait()
        XCTAssertEqual(elements.count, 2)
        
        elements = try connection.send(.zrevrangebyscore(from: key, withScores: 7..<10, limitBy: (offset: 2, count: 3), returning: .valuesOnly)).wait()
        XCTAssertEqual(elements.count, 1)
        
        elements = try connection.send(.zrevrangebyscore(from: key, withMinimumScoreOf: .exclusive(5), returning: .valuesOnly)).wait()
        XCTAssertEqual(elements.count, 5)
        
        elements = try connection.send(.zrevrangebyscore(from: key, withMaximumScoreOf: 5, returning: .valuesOnly)).wait()
        XCTAssertEqual(elements.count, 5)
            
        let elementsAndScores = try connection.send(.zrevrangebyscore(from: key, withScores: 1...3, returning: .valuesAndScores)).wait()
        XCTAssertEqual(elementsAndScores.count, 3)

        let values = elementsAndScores.map(\.1)
        XCTAssertEqual(values[0], 3.0)
        XCTAssertEqual(values[1], 2.0)
        XCTAssertEqual(values[2], 1.0)
    }

    func test_zrangebylex() throws {
        for i in 1...10 {
            _ = try connection.send(.zadd((i, 1), to: #function)).wait()
        }
        
        var elements = try connection.send(.zrangebylex(from: #function, withMinimumValueOf: .exclusive(10)))
            .wait()
            .map(Int.init(fromRESP:))
        XCTAssertEqual(elements.count, 8)
        
        elements = try connection.send(.zrangebylex(from: #function, withMaximumValueOf: .inclusive(5)))
            .wait()
            .map(Int.init(fromRESP:))
        XCTAssertEqual(elements.count, 6)
        
        elements = try connection.send(.zrangebylex(from: #function, withValuesBetween: (.inclusive(1), .inclusive(2))))
            .wait()
            .map(Int.init(fromRESP:))
        
        XCTAssertEqual(elements.count, 3)
        XCTAssertEqual(elements[0], 1)
        XCTAssertEqual(elements[1], 10)
        XCTAssertEqual(elements[2], 2)

        elements = try connection.send(
                .zrangebylex(
                    from: #function,
                    withValuesBetween: (.inclusive(1), .exclusive(4)),
                    limitBy: (offset: 1, count: 1)
                )
            )
            .wait()
            .map(Int.init(fromRESP:))
        XCTAssertEqual(elements.count, 1)
        XCTAssertEqual(elements[0], 10)
    }

    func test_zrevrangebylex() throws {
        for i in 1...10 {
            _ = try connection.send(.zadd((i, 1), to: #function)).wait()
        }
        
        var elements = try connection.send(.zrevrangebylex(from: #function, withMinimumValueOf: .inclusive(1)))
            .wait()
            .map(Int.init(fromRESP:))
        XCTAssertEqual(elements.count, 10)
        XCTAssertEqual(elements[0], 9)
        XCTAssertEqual(elements[9], 1)
        
        elements = try connection.send(.zrevrangebylex(from: #function, withMaximumValueOf: .exclusive(2)))
            .wait()
            .map(Int.init(fromRESP:))
        XCTAssertEqual(elements.count, 2)
        XCTAssertEqual(elements[0], 10)

        elements = try connection.send(.zrevrangebylex(from: #function, withValuesBetween: (.exclusive(2), .inclusive(4))))
            .wait()
            .map(Int.init(fromRESP:))
        XCTAssertEqual(elements.count, 2)
        XCTAssertEqual(elements[0], 4)
        XCTAssertEqual(elements[1], 3)

        elements = try connection.send(
                .zrevrangebylex(
                    from: #function,
                    withValuesBetween: (.inclusive(1), .exclusive(4)),
                    limitBy: (offset: 1, count: 2)
                )
            )
            .wait()
            .map(Int.init(fromRESP:))
        XCTAssertEqual(elements.count, 2)
        XCTAssertEqual(elements[0], 2)
    }

    func test_zrem() throws {
        var count = try connection.send(.zrem(1, from: key)).wait()
        XCTAssertEqual(count, 1)
        count = try connection.send(.zrem([1], from: key)).wait()
        XCTAssertEqual(count, 0)

        count = try connection.send(.zrem(2, 3, 4, 5, from: key)).wait()
        XCTAssertEqual(count, 4)
        count = try connection.send(.zrem([5, 6, 7], from: key)).wait()
        XCTAssertEqual(count, 2)
    }

    func test_zremrangebylex() throws {
        for value in ["bar", "car", "tar"] {
            _ = try connection.send(.zadd((value, 0), to: #function)).wait()
        }

        var count = try connection.send(.zremrangebylex(from: #function, withValuesBetween: (.exclusive("a"), .inclusive("t")))).wait()
        XCTAssertEqual(count, 2)
        
        count = try connection.send(.zremrangebylex(from: #function, withMaximumValueOf: .inclusive("t"))).wait()
        XCTAssertEqual(count, 0)

        count = try connection.send(.zremrangebylex(from: #function, withMinimumValueOf: .inclusive("t"))).wait()
        XCTAssertEqual(count, 1)
    }

    func test_zremrangebyrank() throws {
        var count = try connection.send(.zremrangebyrank(from: key, fromIndex: 9)).wait()
        XCTAssertEqual(count, 1)
        
        count = try connection.send(.zremrangebyrank(from: key, indices: 0...1)).wait()
        XCTAssertEqual(count, 2)
        
        count = try connection.send(.zremrangebyrank(from: key, indices: 0..<2)).wait()
        XCTAssertEqual(count, 2)
        
        count = try connection.send(.zremrangebyrank(from: key, upToIndex: 1)).wait()
        XCTAssertEqual(count, 1)
        
        count = try connection.send(.zremrangebyrank(from: key, throughIndex: 1)).wait()
        XCTAssertEqual(count, 2)
        
        count = try connection.send(.zremrangebyrank(from: key, upToIndex: 0)).wait()
        XCTAssertEqual(count, 2)
    }

    func test_zremrangebyscore() throws {
        var count = try connection.send(.zremrangebyscore(from: key, withScoresBetween: (.exclusive(8), 10))).wait()
        XCTAssertEqual(count, 2)
        
        count = try connection.send(.zremrangebyscore(from: key, withScores: 4..<7)).wait()
        XCTAssertEqual(count, 3)
        
        count = try connection.send(.zremrangebyscore(from: key, withScores: 2...3)).wait()
        XCTAssertEqual(count, 2)
        
        count = try connection.send(.zremrangebyscore(from: key, withMinimumScoreOf: .exclusive(1))).wait()
        XCTAssertEqual(count, 2)
        
        count = try connection.send(.zremrangebyscore(from: key, withMaximumScoreOf: .inclusive(1))).wait()
        XCTAssertEqual(count, 1)
    }
}

// MARK: - #104 zrevrange & zrange bug

extension SortedSetCommandsTests {
    func test_zrange_realworld() throws {
        struct Keys {
            static let first  = "1E4FD2C5-C32E-4E3F-91B3-45478BCF0185"
            static let second = "1E4FD2C5-C32E-4E3F-91B3-45478BCF0186"
            static let third  = "1E4FD2C5-C32E-4E3F-91B3-45478BCF0187"
            static let fourth = "1E4FD2C5-C32E-4E3F-91B3-45478BCF0188"
            static let fifth  = "1E4FD2C5-C32E-4E3F-91B3-45478BCF0189"
        }
        _ = try self.connection.send(.zadd([
            (Keys.first, 1),
            (Keys.second, 1),
            (Keys.third, 1),
            (Keys.fourth, 1),
            (Keys.fifth, 1),
        ], to: #function)).wait()

        let elements = try self.connection.send(.zrange(from: #function, fromIndex: 0, returning: .valuesOnly))
            .wait()
            .compactMap(\.string)

        XCTAssertEqual(elements.count, 5)
        XCTAssertEqual(elements, elements.sorted(by: <))
    }

    func test_zrevrange_realworld() throws {
        struct Keys {
            static let first  = "1E4FD2C5-C32E-4E3F-91B3-45478BCF0185"
            static let second = "1E4FD2C5-C32E-4E3F-91B3-45478BCF0186"
            static let third  = "1E4FD2C5-C32E-4E3F-91B3-45478BCF0187"
            static let fourth = "1E4FD2C5-C32E-4E3F-91B3-45478BCF0188"
            static let fifth  = "1E4FD2C5-C32E-4E3F-91B3-45478BCF0189"
        }
        _ = try self.connection.send(.zadd([
            (Keys.first, 1),
            (Keys.second, 1),
            (Keys.third, 1),
            (Keys.fourth, 1),
            (Keys.fifth, 1),
        ], to: #function)).wait()

        let elements = try self.connection.send(.zrevrange(from: #function, fromIndex: 0, returning: .valuesOnly))
            .wait()
            .compactMap(\.string)

        XCTAssertEqual(elements.count, 5)
        XCTAssertEqual(elements, elements.sorted(by: >))
    }
}
