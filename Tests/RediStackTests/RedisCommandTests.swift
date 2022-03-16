//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2022 RediStack project authors
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

final class RedisCommandTests: XCTestCase { }

// MARK: Equatable Tests

extension RedisCommandTests {
    func test_equatableConformance() {
        let first = RedisCommand<String>(keyword: #function, arguments: [])
        let second = RedisCommand<String>(keyword: #function, arguments: [])
        XCTAssertEqual(first, second)

        let third = RedisCommand<String>(keyword: #function, arguments: [#line.convertedToRESPValue()])
        XCTAssertNotEqual(first, third)
        XCTAssertNotEqual(second, third)

        let fourth = RedisCommand<String>(keyword: "buzz", arguments: [])
        XCTAssertNotEqual(first, fourth)
        XCTAssertNotEqual(third, fourth)
    }
}
