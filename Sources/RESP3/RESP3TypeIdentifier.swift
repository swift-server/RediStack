//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2023 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

enum RESP3TypeIdentifier: UInt8 {
    case integer = 58 // UInt8(ascii: ":")
    case double = 44 // UInt8.comma
    case simpleString = 43 // UInt8.plus
    case simpleError = 45 // UInt8.min
    case blobString = 36 // UInt8.dollar
    case blobError = 33 // UInt8.exclamationMark
    case verbatimString = 61 // UInt8.equals
    case boolean = 35 // UInt8.pound
    case null = 95 // UInt8.underscore
    case bigNumber = 40 // UInt8.leftRoundBracket
    case array = 42 // UInt8.asterisk
    case map = 37 // UInt8.percent
    case set = 126 // UInt8.tilde
    case attribute = 124 // UInt8.pipe
    case push = 62 // UInt8.rightAngledBracket
}

extension UInt8 {
    static let newline = UInt8(ascii: "\n")
    static let carriageReturn = UInt8(ascii: "\r")
    private static let dollar = UInt8(ascii: "$")
    private static let asterisk = UInt8(ascii: "*")
    private static let percent = UInt8(ascii: "%")
    private static let plus = UInt8(ascii: "+")
    private static let hyphen = UInt8(ascii: "-")
    private static let tilde = UInt8(ascii: "~")
    private static let pipe = UInt8(ascii: "|")
    static let colon = UInt8(ascii: ":")
    private static let underscore = UInt8(ascii: "_")
    private static let comma = UInt8(ascii: ",")
    static let pound = UInt8(ascii: "#")
    static let t = UInt8(ascii: "t")
    static let f = UInt8(ascii: "f")
    private static let zero = UInt8(ascii: "0")
    private static let nine = UInt8(ascii: "9")
    private static let exclamationMark = UInt8(ascii: "!")
    private static let equals = UInt8(ascii: "=")
    private static let leftRoundBracket = UInt8(ascii: "(")
    private static let rightAngledBracket = UInt8(ascii: ">")
}

