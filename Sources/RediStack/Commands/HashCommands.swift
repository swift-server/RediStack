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

// MARK: General

extension NewRedisCommand {
    /// Removes the specified fields from a hash.
    ///
    /// See [https://redis.io/commands/hdel](https://redis.io/commands/hdel)
    /// - Parameters:
    ///     - fields: The list of field names that should be removed from the hash.
    ///     - key: The key of the hash to delete from.
    public static func hdel(_ fields: [String], from key: RedisKey) -> NewRedisCommand<Int> {
        var args: [RESPValue] = [.init(bulk: key)]
        args.append(convertingContentsOf: fields)
        return .init(keyword: "HDEL", arguments: args)
    }

    /// Checks if a hash contains the field specified.
    ///
    /// See [https://redis.io/commands/hexists](https://redis.io/commands/hexists)
    /// - Parameters:
    ///     - field: The field name to look for.
    ///     - key: The key of the hash to look within.
    public static func hexists(_ field: String, in key: RedisKey) -> NewRedisCommand<Int> {
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: field)
        ]
        return .init(keyword: "HEXISTS", arguments: args)
    }

    /// Gets the number of fields contained in a hash.
    ///
    /// See [https://redis.io/commands/hlen](https://redis.io/commands/hlen)
    /// - Parameter key: The key of the hash to get field count of.
    public static func hlen(of key: RedisKey) -> NewRedisCommand<Int> {
        let args = [RESPValue(bulk: key)]
        return .init(keyword: "HLEN", arguments: args)
    }

    /// Gets the string length of a hash field's value.
    ///
    /// See [https://redis.io/commands/hstrlen](https://redis.io/commands/hstrlen)
    /// - Parameters:
    ///     - field: The field name whose value is being accessed.
    ///     - key: The key of the hash.
    public static func hstrlen(of field: String, in key: RedisKey) -> NewRedisCommand<Int> {
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: field)
        ]
        return .init(keyword: "HSTRLEN", arguments: args)
    }

    /// Gets all field names in a hash.
    ///
    /// See [https://redis.io/commands/hkeys](https://redis.io/commands/hkeys)
    /// - Parameter key: The key of the hash.
    public static func hkeys(in key: RedisKey) -> NewRedisCommand<[String]> {
        let args = [RESPValue(bulk: key)]
        return .init(keyword: "HKEYS", arguments: args)
    }

    /// Gets all values stored in a hash.
    ///
    /// See [https://redis.io/commands/hvals](https://redis.io/commands/hvals)
    /// - Parameter key: The key of the hash.
    public static func hvals(in key: RedisKey) -> NewRedisCommand<[RESPValue]> {
        let args = [RESPValue(bulk: key)]
        return .init(keyword: "HVALS", arguments: args)
    }

    /// Incrementally iterates over all fields in a hash.
    ///
    /// [https://redis.io/commands/scan](https://redis.io/commands/scan)
    /// - Parameters:
    ///     - key: The key of the hash.
    ///     - position: The position to start the scan from.
    ///     - count: The number of elements to advance by. Redis default is 10.
    ///     - match: A glob-style pattern to filter values to be selected from the result set.
    public static func hscan(
        _ key: RedisKey,
        startingFrom position: UInt = 0,
        count: Int? = nil,
        matching match: String? = nil
    ) -> NewRedisCommand<[RESPValue]> { // Until tuples can conform to protocols, we have to lose type information
        var args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: position)
        ]
        if let m = match { args.append(convertingContentsOf: ["match", m]) }
        if let c = count { args.append(convertingContentsOf: ["count", c.description]) }
        return .init(keyword: "HSCAN", arguments: args)
    }
}

// MARK: Set

extension NewRedisCommand {
    /// Sets a hash field to the value specified.
    /// - Note: If you do not want to overwrite existing values, use `hsetnx(_:field:to:)`.
    ///
    /// See [https://redis.io/commands/hset](https://redis.io/commands/hset)
    /// - Parameters:
    ///     - field: The name of the field in the hash being set.
    ///     - value: The value the hash field should be set to.
    ///     - key: The key that holds the hash.
    @inlinable
    public static func hset<Value: RESPValueConvertible>(
        _ field: String,
        to value: Value,
        in key: RedisKey
    ) -> NewRedisCommand<Int> {
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: field),
            value.convertedToRESPValue()
        ]
        return .init(keyword: "HSET", arguments: args)
    }

    /// Sets a hash field to the value specified only if the field does not currently exist.
    /// - Note: If you do not care about overwriting existing values, use `hset(_:field:to:)`.
    ///
    /// See [https://redis.io/commands/hsetnx](https://redis.io/commands/hsetnx)
    /// - Parameters:
    ///     - field: The name of the field in the hash being set.
    ///     - value: The value the hash field should be set to.
    ///     - key: The key that holds the hash.
    @inlinable
    public static func hsetnx<Value: RESPValueConvertible>(
        _ field: String,
        to value: Value,
        in key: RedisKey
    ) -> NewRedisCommand<Int> {
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: field),
            value.convertedToRESPValue()
        ]
     
        return .init(keyword: "HSETNX", arguments: args)
    }

    /// Sets the fields in a hash to the respective values provided.
    ///
    /// See [https://redis.io/commands/hmset](https://redis.io/commands/hmset)
    /// - Parameters:
    ///     - fields: The key-value pair of field names and their respective values to set.
    ///     - key: The key that holds the hash.
    @inlinable
    public static func hmset<Value: RESPValueConvertible>(
        _ fields: [String: Value],
        in key: RedisKey
    ) -> NewRedisCommand<String> {
        assert(fields.count > 0, "At least 1 key-value pair should be specified")

        var args: [RESPValue] = [.init(bulk: key)]
        args.add(contentsOf: fields, overestimatedCountBeingAdded: fields.count * 2) { (array, element) in
            array.append(.init(bulk: element.key))
            array.append(element.value.convertedToRESPValue())
        }
        return .init(keyword: "HMSET", arguments: args)
    }
}

// MARK: Get

extension NewRedisCommand {
    /// Gets a hash field's value.
    ///
    /// See [https://redis.io/commands/hget](https://redis.io/commands/hget)
    /// - Parameters:
    ///     - field: The name of the field whose value is being accessed.
    ///     - key: The key of the hash being accessed.
    public static func hget(_ field: String, from key: RedisKey) -> NewRedisCommand<String?> {
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: field)
        ]
        return .init(keyword: "HGET", arguments: args)
    }

    /// Gets the values of a hash for the fields specified.
    ///
    /// See [https://redis.io/commands/hmget](https://redis.io/commands/hmget)
    /// - Parameters:
    ///     - fields: A list of field names to get values for.
    ///     - key: The key of the hash being accessed.
    public static func hmget(_ fields: [String], from key: RedisKey) -> NewRedisCommand<[String?]> {
        var args: [RESPValue] = [.init(bulk: key)]
        args.append(convertingContentsOf: fields)
        return .init(keyword: "HMGET", arguments: args)
    }

    /// Returns all the fields and values stored in a hash.
    ///
    /// See [https://redis.io/commands/hgetall](https://redis.io/commands/hgetall)
    /// - Parameter key: The key of the hash to pull from.
    public static func hgetall(from key: RedisKey) -> NewRedisCommand<[String]> {
        let args = [RESPValue(bulk: key)]
        return .init(keyword: "HGETALL", arguments: args)
    }
}

// MARK: Increment

extension NewRedisCommand {
    /// Increments a hash field's value and returns the new value.
    ///
    /// See [https://redis.io/commands/hincrby](https://redis.io/commands/hincrby)
    /// - Parameters:
    ///     - amount: The amount to increment the value stored in the field by.
    ///     - field: The name of the field whose value should be incremented.
    ///     - key: The key of the hash the field is stored in.
    @inlinable
    public static func hincrby<Value>(_ amount: Value, field: String, in key: RedisKey) -> NewRedisCommand<Int>
        where Value: BinaryInteger & RESPValueConvertible
    {
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: field),
            amount.convertedToRESPValue()
        ]
        return .init(keyword: "HINCRBY", arguments: args)
    }

    /// Increments a hash field's value and returns the new value.
    ///
    /// See [https://redis.io/commands/hincrbyfloat](https://redis.io/commands/hincrbyfloat)
    /// - Parameters:
    ///     - amount: The amount to increment the value stored in the field by.
    ///     - field: The name of the field whose value should be incremented.
    ///     - key: The key of the hash the field is stored in.
    @inlinable
    public static func hincrbyfloat<Value>(_ amount: Value, field: String, in key: RedisKey) -> NewRedisCommand<Value>
        where Value: BinaryFloatingPoint & RESPValueConvertible
    {
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: field),
            amount.convertedToRESPValue()
        ]
        return .init(keyword: "HINCRBYFLOAT", arguments: args)
    }
}
