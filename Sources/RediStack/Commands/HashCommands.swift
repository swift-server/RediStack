//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2019-2022 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct Logging.Logger
import NIO

// MARK: Hashes

extension RedisCommand {
    /// [HDEL](https://redis.io/commands/hdel)
    /// - Parameters:
    ///     - fields: The list of field keys that should be removed from the hash.
    ///     - key: The key of the hash to delete from.
    public static func hdel(_ fields: [RedisHashFieldKey], from key: RedisKey) -> RedisCommand<Int> {
        assert(fields.count > 0, "at least 1 field should be provided")
    
        var args = [RESPValue(from: key)]
        args.append(convertingContentsOf: fields)
    
        return .init(keyword: "HDEL", arguments: args)
    }

    /// [HDEL](https://redis.io/commands/hdel)
    /// - Parameters:
    ///     - fields: The list of field keys that should be removed from the hash.
    ///     - key: The key of the hash to delete from.
    public static func hdel(_ fields: RedisHashFieldKey..., from key: RedisKey) -> RedisCommand<Int> {
        return .hdel(fields, from: key)
    }

    /// [HEXISTS](https://redis.io/commands/hexists)
    /// - Parameters:
    ///     - field: The field key to look for.
    ///     - key: The key of the hash to look within.
    public static func hexists(_ field: RedisHashFieldKey, in key: RedisKey) -> RedisCommand<Bool> {
        let args: [RESPValue] = [
            .init(from: key),
            .init(from: field)
        ]
        return .init(keyword: "HEXISTS", arguments: args)
    }

    /// [HGET](https://redis.io/commands/hget)
    /// - Parameters:
    ///     - field: The key of the field whose value is being accessed.
    ///     - key: The key of the hash being accessed.
    public static func hget(_ field: RedisHashFieldKey, from key: RedisKey) -> RedisCommand<RESPValue?> {
        let args: [RESPValue] = [
            .init(from: key),
            .init(from: field)
        ]
        return .init(keyword: "HGET", arguments: args)
    }

    /// [HGETALL](https://redis.io/commands/hgetall)
    /// - Parameter key: The key of the hash to pull from.
    public static func hgetall(from key: RedisKey) -> RedisCommand<[RedisHashFieldKey: RESPValue]> {
        let args = [RESPValue(from: key)]
        return .init(keyword: "HGETALL", arguments: args) {
            let fields = try $0.map(to: [RESPValue].self)
            return try Self._mapHashResponse(fields)
        }
    }

    /// [HINCRBY](https://redis.io/commands/hincrby)
    /// - Parameters:
    ///     - amount: The amount to increment the value stored in the field by.
    ///     - field: The key of the field whose value should be incremented.
    ///     - key: The key of the hash the field is stored in.
    @inlinable
    public static func hincrby<Value: FixedWidthInteger & RESPValueConvertible>(
        _ amount: Value,
        field: RedisHashFieldKey,
        in key: RedisKey
    ) -> RedisCommand<Value> { ._hincr(keyword: "HINCRBY", amount, field, key) }

    /// [HINCRBYFLOAT](https://redis.io/commands/hincrbyfloat)
    /// - Parameters:
    ///     - amount: The amount to increment the value stored in the field by.
    ///     - field: The key of the field whose value should be incremented.
    ///     - key: The key of the hash the field is stored in.
    @inlinable
    public static func hincrbyfloat<Value: BinaryFloatingPoint & RESPValueConvertible>(
        _ amount: Value,
        field: RedisHashFieldKey,
        in key: RedisKey
    ) -> RedisCommand<Value> { ._hincr(keyword: "HINCRBYFLOAT", amount, field, key) }

    /// [HKEYS](https://redis.io/commands/hkeys)
    /// - Parameter key: The key of the hash.
    public static func hkeys(in key: RedisKey) -> RedisCommand<[RedisHashFieldKey]> {
        let args = [RESPValue(from: key)]
        return .init(keyword: "HKEYS", arguments: args)
    }

    /// [HLEN](https://redis.io/commands/hlen)
    /// - Parameter key: The key of the hash to get field count of.
    public static func hlen(of key: RedisKey) -> RedisCommand<Int> {
        let args = [RESPValue(from: key)]
        return .init(keyword: "HLEN", arguments: args)
    }

    /// [HMGET](https://redis.io/commands/hmget)
    /// - Parameters:
    ///     - fields: A list of field keys to get values for.
    ///     - key: The key of the hash being accessed.
    public static func hmget(_ fields: [RedisHashFieldKey], from key: RedisKey) -> RedisCommand<[RESPValue]> {
        assert(fields.count > 0, "at least 1 field key should be provided")
    
        var args = [RESPValue(from: key)]
        args.append(convertingContentsOf: fields)
    
        return .init(keyword: "HMGET", arguments: args)
    }

    /// [HMGET](https://redis.io/commands/hmget)
    /// - Parameters:
    ///     - fields: A list of field keys to get values for.
    ///     - key: The key of the hash being accessed.
    public static func hmget(_ fields: RedisHashFieldKey..., from key: RedisKey) -> RedisCommand<[RESPValue]> {
        return .hmget(fields, from: key)
    }

    /// [HMSET](https://redis.io/commands/hmset)
    /// - Parameters:
    ///     - fields: The key-value pair of field keys and their respective values to set.
    ///     - key: The key that holds the hash.
    public static func hmset(_ fields: [RedisHashFieldKey: RESPValueConvertible], in key: RedisKey) -> RedisCommand<Void> {
        assert(fields.count > 0, "at least 1 key-value pair should be provided")
    
        var args = [RESPValue(from: key)]
        args.add(contentsOf: fields, overestimatedCountBeingAdded: fields.count * 2) { array, element in
            array.append(.init(from: element.key))
            array.append(element.value.convertedToRESPValue())
        }

        return .init(keyword: "HMSET", arguments: args)
    }

    /// [HSET](https://redis.io/commands/hset)
    /// - Note: If you do not want to overwrite existing values, use ``hsetnx(_:to:in:)``.
    /// - Parameters:
    ///     - field: The key of the field in the hash being set.
    ///     - value: The value the hash field should be set to.
    ///     - key: The key that holds the hash.
    @inlinable
    public static func hset<Value: RESPValueConvertible>(
        _ field: RedisHashFieldKey,
        to value: Value,
        in key: RedisKey
    ) -> RedisCommand<Bool> {
        let args: [RESPValue] = [
            .init(from: key),
            .init(from: field),
            value.convertedToRESPValue()
        ]
        return .init(keyword: "HSET", arguments: args)
    }

    /// [HSETNX](https://redis.io/commands/hsetnx)
    /// - Note: If you do not care about overwriting existing values, use ``hset(_:to:in:)``.
    /// - Parameters:
    ///     - field: The key of the field in the hash being set.
    ///     - value: The value the hash field should be set to.
    ///     - key: The key that holds the hash.
    @inlinable
    public static func hsetnx<Value: RESPValueConvertible>(
        _ field: RedisHashFieldKey,
        to value: Value,
        in key: RedisKey
    ) -> RedisCommand<Bool> {
        let args: [RESPValue] = [
            .init(from: key),
            .init(from: field),
            value.convertedToRESPValue()
        ]
        return .init(keyword: "HSETNX", arguments: args)
    }

    /// [HSTRLEN](https://redis.io/commands/hstrlen)
    /// - Parameters:
    ///     - field: The field key whose value is being accessed.
    ///     - key: The key of the hash.
    public static func hstrlen(of field: RedisHashFieldKey, in key: RedisKey) -> RedisCommand<Int> {
        let args: [RESPValue] = [
            .init(from: key),
            .init(from: field)
        ]
        return .init(keyword: "HSTRLEN", arguments: args)
    }

    /// [HVALS](https://redis.io/commands/hvals)
    /// - Parameter key: The key of the hash.
    public static func hvals(in key: RedisKey) -> RedisCommand<[RESPValue]> {
        let args = [RESPValue(from: key)]
        return .init(keyword: "HVALS", arguments: args)
    }

    /// [HSCAN](https://redis.io/commands/hscan)
    /// - Parameters:
    ///     - key: The key of the hash.
    ///     - position: The position to start the scan from.
    ///     - match: A glob-style pattern to filter values to be selected from the result set.
    ///     - count: The number of elements to advance by. Redis default is 10.
    @inlinable
    public static func hscan(
        _ key: RedisKey,
        startingFrom position: Int = 0,
        matching match: String? = nil,
        count: Int? = nil
    ) -> RedisCommand<(Int, [RedisHashFieldKey: RESPValue])> {
        return ._scan(keyword: "HSCAN", key, position, match, count, {
            let values = try $0.map(to: [RESPValue].self)
            return try Self._mapHashResponse(values)
        })
    }
}

// MARK: -

extension RedisClient {
    /// Incrementally iterates over all fields in a hash.
    ///
    /// See ``RedisCommand/hscan(_:startingFrom:matching:count:)``
    /// - Parameters:
    ///     - key: The key of the hash.
    ///     - position: The position to start the scan from.
    ///     - match: A glob-style pattern to filter values to be selected from the result set.
    ///     - count: The number of elements to advance by. Redis default is 10.
    ///     - eventLoop: An optional event loop to hop to for any further chaining on the returned event loop future.
    ///     - logger: An optional logger instance to use for logs generated from this command.
    /// - Returns: A `NIO.EventLoopFuture` that resolves a cursor position for additional scans,
    ///     with a limited collection of fields and their associated values that were iterated over.
    public func scanHashFields(
        in key: RedisKey,
        startingFrom position: Int = 0,
        matching match: String? = nil,
        count: Int? = nil,
        eventLoop: EventLoop? = nil,
        logger: Logger? = nil
    ) -> EventLoopFuture<(Int, [RedisHashFieldKey: RESPValue])> {
        return self.send(.hscan(key, startingFrom: position, matching: match, count: count), eventLoop: eventLoop, logger: logger)
    }
}

// MARK: -

/// A representation of a Redis hash field key.
///
/// `RedisHashFieldKey` is a thin wrapper around `String` to provide stronger type-safety at compile-time with regards to the domain semantics of any
/// give `String` value.
///
/// It conforms to `ExpressibleByStringLiteral` and `ExpressibleByStringInterpolation`, so creating a hash field key is as simple as:
/// ```swift
/// let fieldKey: RedisHashFieldKey = "foo" // or "\(someVar)"
/// ```
public struct RedisHashFieldKey:
    RESPValueConvertible,
    RawRepresentable,
    ExpressibleByStringLiteral, ExpressibleByStringInterpolation,
    CustomStringConvertible, CustomDebugStringConvertible,
    Comparable, Hashable, Codable
{
    public let rawValue: String

    /// Creates a type-safe representation of a key to a Redis hash field.
    /// - Parameter key: The key of the Redis hash field.
    public init(_ key: String) { self.rawValue = key }

    public var description: String { self.rawValue }
    public var debugDescription: String { "\(String(describing: type(of: self))): \(self.rawValue)"}

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

    public static func <(lhs: RedisHashFieldKey, rhs: RedisHashFieldKey) -> Bool { lhs.rawValue < rhs.rawValue }

    public func convertedToRESPValue() -> RESPValue { .init(bulk: self.rawValue) }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

// MARK: - Shared implementations
extension RedisCommand {
    @usableFromInline
    internal static func _mapHashResponse(_ values: [RESPValue]) throws -> [RedisHashFieldKey: RESPValue] {
        guard values.count > 0 else { return [:] }

        var result: [RedisHashFieldKey: RESPValue] = [:]

        var index = 0
        repeat {
            guard let field = RedisHashFieldKey(fromRESP: values[index]) else {
                throw RedisClientError.assertionFailure(
                    message: "Received non-string value where string hash field key was expected. Raw Value: \(values[index])"
                )
            }
            let value = values[index + 1]
            result[field] = value
            index += 2
        } while (index < values.count)

        return result
    }

    @usableFromInline
    internal static func _hincr<Value: RESPValueConvertible>(
        keyword: String,
        _ amount: Value,
        _ field: RedisHashFieldKey,
        _ key: RedisKey
    ) -> RedisCommand<Value> {
        let args: [RESPValue] = [
            .init(from: key),
            .init(from: field),
            amount.convertedToRESPValue()
        ]
        return .init(keyword: keyword, arguments: args)
    }
}
