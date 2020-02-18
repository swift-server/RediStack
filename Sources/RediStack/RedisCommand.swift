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

import NIO

/// A representation of a Redis Command to be executed against a Redis instance.
///
/// As the arguments are stored in their `RESPValue` format, use the `Sequence.map(as:)` extension to check the values.
public struct NewRedisCommand<ResponseType: RESPValueConvertible> {
    public let keyword: String
    public let arguments: [RESPValue]

    public init(keyword: String, arguments: [RESPValue]) {
        self.keyword = keyword
        self.arguments = arguments
    }

    /// Writes the full command into a single value for sending to Redis.
    /// - Returns: A single `RESPValue.array` value with the keyword as the first element.
    public func serialized() -> RESPValue {
        var message: [RESPValue] = [.init(bulk: self.keyword)]
        message.append(contentsOf: self.arguments)
        return .array(message)
    }
}

// MARK: Equatable

extension NewRedisCommand: Equatable {
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.keyword == rhs.keyword && lhs.arguments.count == rhs.arguments.count
    }
}

// MARK: CustomDebugStringConvertible

extension NewRedisCommand: CustomDebugStringConvertible {
    public var debugDescription: String {
        return """
        Redis Command: '\(self.keyword)'
            Arguments: [\(self.arguments.map({ $0.description }).joined(separator: "\n"))]
            Returns: \(ResponseType.self)
"""
    }
}
