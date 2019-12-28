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
/// It conforms to `ExpressibleByStringLiteral`, so creating a key is simple:
/// ```swift
/// let key: RedisKey = "foo"
/// ```
public struct RedisKey: RawRepresentable {
    public typealias RawValue = String
    
    public let rawValue: String
    
    /// Initializes a type-safe representation of a key to a value in a Redis instance.
    /// - Parameter key: The key of a value in a Redis instance.
    public init(_ key: String) {
        self.rawValue = key
    }
    
    public init?(rawValue: String) {
        self.rawValue = rawValue
    }
}

// MARK: ExpressibleByStringLiteral

extension RedisKey: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.rawValue = value
    }
}

// MARK: CustomStringConvertible

extension RedisKey: CustomStringConvertible {
    public var description: String { return self.rawValue }
}

// MARK: CustomDebugStringConvertible

extension RedisKey: CustomDebugStringConvertible {
    public var debugDescription: String { return "RedisKey: \(self.rawValue)" }
}

// MARK: Comparable && Equatable

extension RedisKey: Comparable {
    public static func <(lhs: RedisKey, rhs: RedisKey) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    public static func ==(lhs: RedisKey, rhs: RedisKey) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
}

// MARK: Hashable

extension RedisKey: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.rawValue)
    }
}

// MARK: Codable

extension RedisKey: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

// MARK: RESPValue

extension RESPValue {
    /// Initializes a `bulkString` value from the `RedisKey`.
    /// - Prameter key: The RedisKey to store in a `.bulkString` representation.
    public init(bulk key: RedisKey) {
        self = .init(bulk: key.rawValue)
    }
}

// MARK: RESPValueConvertible

extension RedisKey: RESPValueConvertible {
    public init?(fromRESP value: RESPValue) {
        guard let string = value.string else { return nil }
        self.rawValue = string
    }
    
    public func convertedToRESPValue() -> RESPValue {
        return .init(bulk: self.rawValue)
    }
}
