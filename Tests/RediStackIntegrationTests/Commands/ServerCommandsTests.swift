//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2020 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import RediStack
import RediStackTestUtils
import XCTest

final class ServerCommandsTests: RediStackIntegrationTestCase {
    func test_swapDatabase() throws {
        try connection.set("first", to: "3").wait()
        var first = try connection.get("first", as: String.self).wait()
        XCTAssertEqual(first, "3")

        try connection.select(database: 1).wait()
        var second = try connection.get("first", as: String.self).wait()
        XCTAssertEqual(second, nil)

        try connection.set("second", to: "100").wait()
        second = try connection.get("second", as: String.self).wait()
        XCTAssertEqual(second, "100")

        let success = try connection.swapDatabase(0, with: 1).wait()
        XCTAssertEqual(success, true)

        second = try connection.get("first", as: String.self).wait()
        XCTAssertEqual(second, "3")

        try connection.select(database: 0).wait()
        first = try connection.get("second", as: String.self).wait()
        XCTAssertEqual(first, "100")
    }
}
