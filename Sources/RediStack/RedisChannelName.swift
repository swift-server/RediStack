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

/// A representation of a Redis Pub/Sub channel.
///
/// `RedisChannelName` is a thin wrapper around `String`, to provide stronger type-safety at compile time.
///
/// It conforms to `ExpressibleByStringLiteral` and `ExpressibleByStringInterpolation`, so creating an instance is simple:
/// ```swift
/// let channel: RedisChannelName = "channel1" // or "\(channelNameVariable)"
/// ```
public struct RedisChannelName:
    RESPValueConvertible,
    RawRepresentable,
    ExpressibleByStringLiteral,
    ExpressibleByStringInterpolation,
    CustomStringConvertible, CustomDebugStringConvertible,
    Comparable, Hashable, Codable
{
    public let rawValue: String
    
    /// Initializes a type-safe representation of a Redis Pub/Sub channel name.
    /// - Parameter name: The name of the Redis Pub/Sub channel.
    public init(_ name: String) {
        self.rawValue = name
    }
    
    public var description: String { self.rawValue }
    public var debugDescription: String { "\(Self.self): \(self.rawValue)" }
    
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
    
    public static func <(lhs: RedisChannelName, rhs: RedisChannelName) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    public func convertedToRESPValue() -> RESPValue {
        return .init(bulk: self.rawValue)
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}
