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

@testable import RediStack
import XCTest
import NIOCore

final class RESP3Tests: XCTestCase {
    func testRESP3IntegerToken() throws {
        var buffer = ByteBuffer(string: ":10\r\n")
        let token = try RESP3Token.validate(consuming: &buffer)
        XCTAssertEqual(token.type, .integer)
    }

    func testRESP3FailsOnNonTerminatedIntegerToken() throws {
        var buffer = ByteBuffer(string: ":10")
        XCTAssertThrowsError(try RESP3Token.validate(consuming: &buffer))
    }
}
