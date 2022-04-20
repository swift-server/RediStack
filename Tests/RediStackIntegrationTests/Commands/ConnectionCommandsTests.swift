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

final class ConnectionCommandsTests: RediStackIntegrationTestCase {
    func test_ping() throws {
        let first = try connection.ping().wait()
        XCTAssertEqual(first, "PONG")

        let second = try connection.ping(with: "My message").wait()
        XCTAssertEqual(second, "My message")

        let third = try connection.send(.ping).wait()
        XCTAssertEqual(third, first)
    }

    func test_echo() throws {
        let response = try connection.send(.echo("FIZZ_BUZZ")).wait()
        XCTAssertEqual(response, "FIZZ_BUZZ")
    }

    func test_select() {
        XCTAssertNoThrow(try connection.select(database: 3).wait())
    }
}
