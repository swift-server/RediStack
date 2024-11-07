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

/// A representation of a key in Redis.
///
/// `RedisKey` is a thin wrapper around `String`, to provide stronger type-safety at compile-time.
///
/// It conforms to `ExpressibleByStringLiteral` and `ExpressibleByStringInterpolation`, so creating
/// a key is simple:
/// ```swift
/// let key: RedisKey = "foo" // or "\(someVar)"
/// ```
public struct RedisKey:
    RESPValueConvertible,
    RawRepresentable,
    ExpressibleByStringLiteral,
    ExpressibleByStringInterpolation,
    CustomStringConvertible, CustomDebugStringConvertible,
    Comparable, Hashable, Codable
{
    public let rawValue: String

    /// Initializes a type-safe representation of a key to a value in a Redis instance.
    /// - Parameter key: The key of a value in a Redis instance.
    public init(_ key: String) {
        self.rawValue = key
    }

    public var description: String { self.rawValue }
    public var debugDescription: String { "\(String(describing: type(of: self))): \(self.rawValue)" }

    public init?(fromRESP value: RESPValue) {
        guard let string = value.string else { return nil }
        self.rawValue = string
    }
    public init?(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    public static func < (lhs: RedisKey, rhs: RedisKey) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public func convertedToRESPValue() -> RESPValue {
        .init(bulk: self.rawValue)
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}
