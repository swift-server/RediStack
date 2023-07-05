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

import NIOCore

/// This error is thrown if a RESP3 package could not be decoded.
///
/// If you see this error, there a two potential reasons this might happen:
///
///   1. The Swift RESP3 implementation is wrong
///   2. You are contacting an untrusted backend
///
struct RESP3ParsingError: Error {
    struct Code: Hashable, Sendable, CustomStringConvertible {
        private enum Base {
            case invalidLeadingByte
            case invalidData
            case tooDepplyNestedAggregatedTypes
            case missingColonInVerbatimString
            case canNotParseInteger
            case canNotParseDouble
            case canNotParseBigNumber
        }

        private let base: Base

        private init(_ base: Base) {
            self.base = base
        }

        static let invalidLeadingByte = Self.init(.invalidLeadingByte)
        static let invalidData = Self.init(.invalidData)
        static let tooDepplyNestedAggregatedTypes = Self.init(.tooDepplyNestedAggregatedTypes)
        static let missingColonInVerbatimString = Self.init(.missingColonInVerbatimString)
        static let canNotParseInteger = Self.init(.canNotParseInteger)
        static let canNotParseDouble = Self.init(.canNotParseDouble)
        static let canNotParseBigNumber = Self.init(.canNotParseBigNumber)

        var description: String {
            switch self.base {
            case .invalidLeadingByte:
                return "invalidLeadingByte"
            case .invalidData:
                return "invalidData"
            case .tooDepplyNestedAggregatedTypes:
                return "tooDepplyNestedAggregatedTypes"
            case .missingColonInVerbatimString:
                return "missingColonInVerbatimString"
            case .canNotParseInteger:
                return "canNotParseInteger"
            case .canNotParseDouble:
                return "canNotParseDouble"
            case .canNotParseBigNumber:
                return "canNotParseBigNumber"
            }
        }
    }

    var code: Code

    var buffer: ByteBuffer
}

enum RESP3Error: Error, Equatable {
    case dataMalformed
    case invalidType(UInt8)
    case tooDepplyNestedAggregatedTypes
}
