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
import XCTest

final class ExtensionTests: XCTestCase {
    func testString_sha1() {
        let str = "Hello String Test"
        guard let hash = str.sha1 else {
            XCTFail()
            return
        }
        XCTAssertEqual(hash, "9c0015411ab9150a115d4730dc2c940d94913402")
    }
}
