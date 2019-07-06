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

import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(RedisByteDecoderTests.allTests),
        testCase(RedisMessageEncoderTests.allTests),
        testCase(RESPTranslatorTests.allTests),
        testCase(BasicCommandsTests.allTests),
        testCase(SetCommandsTests.allTests),
        testCase(HashCommandsTests.allTests),
        testCase(ListCommandsTests.allTests),
        testCase(SortedSetCommandsTests.allTests),
        testCase(StringCommandsTests.allTests),
        testCase(RedisConnectionTests.allTests)
    ]
}
#endif
