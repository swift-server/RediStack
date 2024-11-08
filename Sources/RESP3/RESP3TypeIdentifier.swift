//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2023 Apple Inc. and the RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

enum RESP3TypeIdentifier: UInt8 {
    case integer = 58  // UInt8(ascii: ":")
    case double = 44  // UInt8.comma
    case simpleString = 43  // UInt8.plus
    case simpleError = 45  // UInt8.min
    case blobString = 36  // UInt8.dollar
    case blobError = 33  // UInt8.exclamationMark
    case verbatimString = 61  // UInt8.equals
    case boolean = 35  // UInt8.pound
    case null = 95  // UInt8.underscore
    case bigNumber = 40  // UInt8.leftRoundBracket
    case array = 42  // UInt8.asterisk
    case map = 37  // UInt8.percent
    case set = 126  // UInt8.tilde
    case attribute = 124  // UInt8.pipe
    case push = 62  // UInt8.rightAngledBracket
}

extension UInt8 {
    static let newline = UInt8(ascii: "\n")
    static let carriageReturn = UInt8(ascii: "\r")
    static let colon = UInt8(ascii: ":")
    static let pound = UInt8(ascii: "#")
    static let t = UInt8(ascii: "t")
    static let f = UInt8(ascii: "f")
}
