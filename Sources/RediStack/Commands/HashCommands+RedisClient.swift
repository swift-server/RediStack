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

// MARK: General

extension RedisClient {
    /// Removes the specified fields from a hash.
    ///
    /// See [https://redis.io/commands/hdel](https://redis.io/commands/hdel)
    /// - Parameters:
    ///     - fields: The list of field names that should be removed from the hash.
    ///     - key: The key of the hash to delete from.
    /// - Returns: The number of fields that were deleted.
    public func hdel(_ fields: [String], from key: RedisKey) -> EventLoopFuture<Int> {
        guard fields.count > 0 else { return self.eventLoop.makeSucceededFuture(0) }
        return self.sendCommand(.hdel(fields, from: key))
    }

    /// Removes the specified fields from a hash.
    ///
    /// See [https://redis.io/commands/hdel](https://redis.io/commands/hdel)
    /// - Parameters:
    ///     - fields: The list of field names that should be removed from the hash.
    ///     - key: The key of the hash to delete from.
    /// - Returns: The number of fields that were deleted.
    public func hdel(_ fields: String..., from key: RedisKey) -> EventLoopFuture<Int> {
        return self.hdel(fields, from: key)
    }

    /// Checks if a hash contains the field specified.
    ///
    /// See [https://redis.io/commands/hexists](https://redis.io/commands/hexists)
    /// - Parameters:
    ///     - field: The field name to look for.
    ///     - key: The key of the hash to look within.
    /// - Returns: `true` if the hash contains the field, `false` if either the key or field do not exist.
    public func hexists(_ field: String, in key: RedisKey) -> EventLoopFuture<Bool> {
        return self.sendCommand(.hexists(field, in: key))
            .map { return $0 == 1 }
    }

    /// Gets the number of fields contained in a hash.
    ///
    /// See [https://redis.io/commands/hlen](https://redis.io/commands/hlen)
    /// - Parameter key: The key of the hash to get field count of.
    /// - Returns: The number of fields in the hash, or `0` if the key doesn't exist.
    public func hlen(of key: RedisKey) -> EventLoopFuture<Int> {
        return self.sendCommand(.hlen(of: key))
    }

    /// Gets the string length of a hash field's value.
    ///
    /// See [https://redis.io/commands/hstrlen](https://redis.io/commands/hstrlen)
    /// - Parameters:
    ///     - field: The field name whose value is being accessed.
    ///     - key: The key of the hash.
    /// - Returns: The string length of the hash field's value, or `0` if the field or hash do not exist.
    public func hstrlen(of field: String, in key: RedisKey) -> EventLoopFuture<Int> {
        return self.sendCommand(.hstrlen(of: field, in: key))
    }

    /// Gets all field names in a hash.
    ///
    /// See [https://redis.io/commands/hkeys](https://redis.io/commands/hkeys)
    /// - Parameter key: The key of the hash.
    /// - Returns: A list of field names stored within the hash.
    public func hkeys(in key: RedisKey) -> EventLoopFuture<[String]> {
        return self.sendCommand(.hkeys(in: key))
    }

    /// Gets all values stored in a hash.
    ///
    /// See [https://redis.io/commands/hvals](https://redis.io/commands/hvals)
    /// - Parameter key: The key of the hash.
    /// - Returns: A list of all values stored in a hash.
    public func hvals(in key: RedisKey) -> EventLoopFuture<[RESPValue]> {
        return self.sendCommand(.hvals(in: key))
    }
}

// MARK: Set

extension RedisClient {
    /// Sets a hash field to the value specified.
    /// - Note: If you do not want to overwrite existing values, use `hsetnx(_:field:to:)`.
    ///
    /// See [https://redis.io/commands/hset](https://redis.io/commands/hset)
    /// - Parameters:
    ///     - field: The name of the field in the hash being set.
    ///     - value: The value the hash field should be set to.
    ///     - key: The key that holds the hash.
    /// - Returns: `true` if the hash was created, `false` if it was updated.
    @inlinable
    public func hset<Value: RESPValueConvertible>(
        _ field: String,
        to value: Value,
        in key: RedisKey
    ) -> EventLoopFuture<Bool> {
        return self.sendCommand(.hset(field, to: value, in: key))
            .map { return $0 == 1 }
    }

    /// Sets a hash field to the value specified only if the field does not currently exist.
    /// - Note: If you do not care about overwriting existing values, use `hset(_:field:to:)`.
    ///
    /// See [https://redis.io/commands/hsetnx](https://redis.io/commands/hsetnx)
    /// - Parameters:
    ///     - field: The name of the field in the hash being set.
    ///     - value: The value the hash field should be set to.
    ///     - key: The key that holds the hash.
    /// - Returns: `true` if the hash was created.
    @inlinable
    public func hsetnx<Value: RESPValueConvertible>(
        _ field: String,
        to value: Value,
        in key: RedisKey
    ) -> EventLoopFuture<Bool> {
        return self.sendCommand(.hsetnx(field, to: value, in: key))
            .map { return $0 == 1 }
    }

    /// Sets the fields in a hash to the respective values provided.
    ///
    /// See [https://redis.io/commands/hmset](https://redis.io/commands/hmset)
    /// - Parameters:
    ///     - fields: The key-value pair of field names and their respective values to set.
    ///     - key: The key that holds the hash.
    /// - Returns: An `EventLoopFuture` that resolves when the operation has succeeded, or fails with a `RedisError`.
    @inlinable
    public func hmset<Value: RESPValueConvertible>(
        _ fields: [String: Value],
        in key: RedisKey
    ) -> EventLoopFuture<Void> {
        return self.sendCommand(.hmset(fields, in: key))
            .map { _ in return () }
    }
}
    
// MARK: Get

extension RedisClient {
    /// Gets a hash field's value.
    ///
    /// See [https://redis.io/commands/hget](https://redis.io/commands/hget)
    /// - Parameters:
    ///     - field: The name of the field whose value is being accessed.
    ///     - key: The key of the hash being accessed.
    /// - Returns: The value of the hash field, or `nil` if either the key or field does not exist.
    public func hget(_ field: String, from key: RedisKey) -> EventLoopFuture<String?> {
        return self.sendCommand(.hget(field, from: key))
    }

    /// Gets the values of a hash for the fields specified.
    ///
    /// See [https://redis.io/commands/hmget](https://redis.io/commands/hmget)
    /// - Parameters:
    ///     - fields: A list of field names to get values for.
    ///     - key: The key of the hash being accessed.
    /// - Returns: A list of values in the same order as the `fields` argument. Non-existent fields return `nil` values.
    public func hmget(_ fields: [String], from key: RedisKey) -> EventLoopFuture<[String?]> {
        guard fields.count > 0 else { return self.eventLoop.makeSucceededFuture([]) }
        return self.sendCommand(.hmget(fields, from: key))
    }

    /// Gets the values of a hash for the fields specified.
    ///
    /// See [https://redis.io/commands/hmget](https://redis.io/commands/hmget)
    /// - Parameters:
    ///     - fields: A list of field names to get values for.
    ///     - key: The key of the hash being accessed.
    /// - Returns: A list of values in the same order as the `fields` argument. Non-existent fields return `nil` values.
    public func hmget(_ fields: String..., from key: RedisKey) -> EventLoopFuture<[String?]> {
        return self.hmget(fields, from: key)
    }

    /// Returns all the fields and values stored in a hash.
    ///
    /// See [https://redis.io/commands/hgetall](https://redis.io/commands/hgetall)
    /// - Parameter key: The key of the hash to pull from.
    /// - Returns: A key-value pair list of fields and their values.
    public func hgetall(from key: RedisKey) -> EventLoopFuture<[String: String]> {
        return self.sendCommand(.hgetall(from: key))
            .map(Self._mapHashFieldResponse)
    }
}
    
// MARK: Increment

extension RedisClient {
    /// Increments a hash field's value and returns the new value.
    ///
    /// See [https://redis.io/commands/hincrby](https://redis.io/commands/hincrby)
    /// - Parameters:
    ///     - amount: The amount to increment the value stored in the field by.
    ///     - field: The name of the field whose value should be incremented.
    ///     - key: The key of the hash the field is stored in.
    /// - Returns: The new value of the hash field.
    @inlinable
    public func hincrby<Value>(_ amount: Value, field: String, in key: RedisKey) -> EventLoopFuture<Int>
        where Value: BinaryInteger & RESPValueConvertible
    {
        return self.sendCommand(.hincrby(amount, field: field, in: key))
    }

    /// Increments a hash field's value and returns the new value.
    ///
    /// See [https://redis.io/commands/hincrbyfloat](https://redis.io/commands/hincrbyfloat)
    /// - Parameters:
    ///     - amount: The amount to increment the value stored in the field by.
    ///     - field: The name of the field whose value should be incremented.
    ///     - key: The key of the hash the field is stored in.
    /// - Returns: The new value of the hash field.
    @inlinable
    public func hincrbyfloat<Value>(_ amount: Value, field: String, in key: RedisKey) -> EventLoopFuture<Value>
        where
        Value: BinaryFloatingPoint & RESPValueConvertible
    {
        return self.sendCommand(.hincrbyfloat(amount, field: field, in: key))
    }

    /// Incrementally iterates over all fields in a hash.
    ///
    /// [https://redis.io/commands/scan](https://redis.io/commands/scan)
    /// - Parameters:
    ///     - key: The key of the hash.
    ///     - position: The position to start the scan from.
    ///     - count: The number of elements to advance by. Redis default is 10.
    ///     - match: A glob-style pattern to filter values to be selected from the result set.
    /// - Returns: A cursor position for additional invocations with a limited collection of found fields and their values.
    public func hscan(
        _ key: RedisKey,
        startingFrom position: UInt = 0,
        count: Int? = nil,
        matching match: String? = nil
    ) -> EventLoopFuture<(UInt, [String: String])> { 
        return self._sendScanCommand(.hscan(key, startingFrom: position, count: count, matching: match))
            .map { return ($0.0, Self._mapHashFieldResponse($0.1)) }
    }
}

// MARK: Static Helper

extension RedisClient {
    @usableFromInline
    internal static func _mapHashFieldResponse(_ values: [String]) -> [String: String] {
        guard values.count > 0 else { return [:] }

        var result: [String: String] = [:]

        var index = 0
        repeat {
            let field = values[index]
            let value = values[index + 1]
            result[field] = value
            index += 2
        } while (index < values.count)

        return result
    }
}
