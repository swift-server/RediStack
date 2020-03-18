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

// MARK: Static Helpers

extension RedisClient {
    @usableFromInline
    internal static func _mapHashResponse(_ values: [RESPValue]) throws -> [String: RESPValue] {
        guard values.count > 0 else { return [:] }

        var result: [String: RESPValue] = [:]

        var index = 0
        repeat {
            guard let field = String(fromRESP: values[index]) else {
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
}

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
        
        var args: [RESPValue] = [.init(bulk: key)]
        args.append(convertingContentsOf: fields)

        return send(command: "HDEL", with: args)
            .map()
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
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: field)
        ]
        return send(command: "HEXISTS", with: args)
            .map(to: Int.self)
            .map { return $0 == 1 }
    }

    /// Gets the number of fields contained in a hash.
    ///
    /// See [https://redis.io/commands/hlen](https://redis.io/commands/hlen)
    /// - Parameter key: The key of the hash to get field count of.
    /// - Returns: The number of fields in the hash, or `0` if the key doesn't exist.
    public func hlen(of key: RedisKey) -> EventLoopFuture<Int> {
        let args = [RESPValue(bulk: key)]
        return send(command: "HLEN", with: args)
            .map()
    }

    /// Gets the string length of a hash field's value.
    ///
    /// See [https://redis.io/commands/hstrlen](https://redis.io/commands/hstrlen)
    /// - Parameters:
    ///     - field: The field name whose value is being accessed.
    ///     - key: The key of the hash.
    /// - Returns: The string length of the hash field's value, or `0` if the field or hash do not exist.
    public func hstrlen(of field: String, in key: RedisKey) -> EventLoopFuture<Int> {
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: field)
        ]
        return send(command: "HSTRLEN", with: args)
            .map()
    }

    /// Gets all field names in a hash.
    ///
    /// See [https://redis.io/commands/hkeys](https://redis.io/commands/hkeys)
    /// - Parameter key: The key of the hash.
    /// - Returns: A list of field names stored within the hash.
    public func hkeys(in key: RedisKey) -> EventLoopFuture<[String]> {
        let args = [RESPValue(bulk: key)]
        return send(command: "HKEYS", with: args)
            .map()
    }

    /// Gets all values stored in a hash.
    ///
    /// See [https://redis.io/commands/hvals](https://redis.io/commands/hvals)
    /// - Parameter key: The key of the hash.
    /// - Returns: A list of all values stored in a hash.
    public func hvals(in key: RedisKey) -> EventLoopFuture<[RESPValue]> {
        let args = [RESPValue(bulk: key)]
        return send(command: "HVALS", with: args)
            .map()
    }
    
    /// Gets all values stored in a hash.
    ///
    /// See [https://redis.io/commands/hvals](https://redis.io/commands/hvals)
    /// - Parameters:
    ///     - key: The key of the hash.
    ///     - type: The type to convert the values to.
    /// - Returns: A list of all values stored in a hash.
    @inlinable
    public func hvals<Value: RESPValueConvertible>(in key: RedisKey, as type: Value.Type) -> EventLoopFuture<[Value?]> {
        return self.hvals(in: key)
            .map { return $0.map(Value.init(fromRESP:)) }
    }

    /// Incrementally iterates over all fields in a hash.
    ///
    /// [https://redis.io/commands/scan](https://redis.io/commands/scan)
    /// - Parameters:
    ///     - key: The key of the hash.
    ///     - position: The position to start the scan from.
    ///     - match: A glob-style pattern to filter values to be selected from the result set.
    ///     - count: The number of elements to advance by. Redis default is 10.
    ///     - valueType: The type to cast all values to.
    /// - Returns: A cursor position for additional invocations with a limited collection of found fields and their values.
    @inlinable
    public func hscan<Value: RESPValueConvertible>(
        _ key: RedisKey,
        startingFrom position: Int = 0,
        matching match: String? = nil,
        count: Int? = nil,
        valueType: Value.Type
    ) -> EventLoopFuture<(Int, [String: Value?])> {
        return self.hscan(key, startingFrom: position, matching: match, count: count)
            .map { (cursor, fields) in
                let mappedFields = fields.mapValues(Value.init(fromRESP:))
                return (cursor, mappedFields)
            }
    }

    /// Incrementally iterates over all fields in a hash.
    ///
    /// [https://redis.io/commands/scan](https://redis.io/commands/scan)
    /// - Parameters:
    ///     - key: The key of the hash.
    ///     - position: The position to start the scan from.
    ///     - match: A glob-style pattern to filter values to be selected from the result set.
    ///     - count: The number of elements to advance by. Redis default is 10.
    /// - Returns: A cursor position for additional invocations with a limited collection of found fields and their values.
    public func hscan(
        _ key: RedisKey,
        startingFrom position: Int = 0,
        matching match: String? = nil,
        count: Int? = nil
    ) -> EventLoopFuture<(Int, [String: RESPValue])> {
        return _scan(command: "HSCAN", resultType: [RESPValue].self, key, position, match, count)
            .flatMapThrowing {
                let values = try Self._mapHashResponse($0.1)
                return ($0.0, values)
            }
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
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: field),
            value.convertedToRESPValue()
        ]
        return send(command: "HSET", with: args)
            .map(to: Int.self)
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
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: field),
            value.convertedToRESPValue()
        ]
        return send(command: "HSETNX", with: args)
            .map(to: Int.self)
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
        assert(fields.count > 0, "At least 1 key-value pair should be specified")

        var args: [RESPValue] = [.init(bulk: key)]
        args.add(contentsOf: fields, overestimatedCountBeingAdded: fields.count * 2) { (array, element) in
            array.append(.init(bulk: element.key))
            array.append(element.value.convertedToRESPValue())
        }
        
        return send(command: "HMSET", with: args)
            .map { _ in () }
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
    /// - Returns: The value of the hash field. If the key or field does not exist, it will be `.null`.
    public func hget(_ field: String, from key: RedisKey) -> EventLoopFuture<RESPValue> {
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: field)
        ]
        return send(command: "HGET", with: args)
    }
    
    /// Gets a hash field's value as the desired type.
    ///
    /// See [https://redis.io/commands/hget](https://redis.io/commands/hget)
    /// - Parameters:
    ///     - field: The name of the field whose value is being accessed.
    ///     - key: The key of the hash being accessed.
    ///     - type: The type to convert the value to.
    /// - Returns: The value of the hash field, or `nil` if the `RESPValue` conversion fails or either the key or field does not exist.
    @inlinable
    public func hget<Value: RESPValueConvertible>(
        _ field: String,
        from key: RedisKey,
        as type: Value.Type
    ) -> EventLoopFuture<Value?> {
        return self.hget(field, from: key)
            .map(Value.init(fromRESP:))
    }

    /// Gets the values of a hash for the fields specified.
    ///
    /// See [https://redis.io/commands/hmget](https://redis.io/commands/hmget)
    /// - Parameters:
    ///     - fields: A list of field names to get values for.
    ///     - key: The key of the hash being accessed.
    /// - Returns: A list of values in the same order as the `fields` argument. Non-existent fields return `.null` values.
    public func hmget(_ fields: [String], from key: RedisKey) -> EventLoopFuture<[RESPValue]> {
        guard fields.count > 0 else { return self.eventLoop.makeSucceededFuture([]) }
        
        var args: [RESPValue] = [.init(bulk: key)]
        args.append(convertingContentsOf: fields)

        return send(command: "HMGET", with: args)
            .map(to: [RESPValue].self)
    }

    /// Gets the values of a hash for the fields specified as a specific type.
    ///
    /// See [https://redis.io/commands/hmget](https://redis.io/commands/hmget)
    /// - Parameters:
    ///     - fields: A list of field names to get values for.
    ///     - key: The key of the hash being accessed.
    ///     - type: The type to convert the values to.
    /// - Returns: A list of values in the same order as the `fields` argument. Non-existent fields and elements that fail the `RESPValue` conversion return `nil` values.
    @inlinable
    public func hmget<Value: RESPValueConvertible>(
        _ fields: [String],
        from key: RedisKey,
        as type: Value.Type
    ) -> EventLoopFuture<[Value?]> {
        return self.hmget(fields, from: key)
            .map { return $0.map(Value.init(fromRESP:)) }
    }
    
    /// Gets the values of a hash for the fields specified.
    ///
    /// See [https://redis.io/commands/hmget](https://redis.io/commands/hmget)
    /// - Parameters:
    ///     - fields: A list of field names to get values for.
    ///     - key: The key of the hash being accessed.
    /// - Returns: A list of values in the same order as the `fields` argument. Non-existent fields return `.null` values.
    public func hmget(_ fields: String..., from key: RedisKey) -> EventLoopFuture<[RESPValue]> {
        return self.hmget(fields, from: key)
    }

    /// Gets the values of a hash for the fields specified.
    ///
    /// See [https://redis.io/commands/hmget](https://redis.io/commands/hmget)
    /// - Parameters:
    ///     - fields: A list of field names to get values for.
    ///     - key: The key of the hash being accessed.
    ///     - type: The type to convert the values to.
    /// - Returns: A list of values in the same order as the `fields` argument. Non-existent fields and elements that fail the `RESPValue` conversion return `nil` values.
    @inlinable
    public func hmget<Value: RESPValueConvertible>(
        _ fields: String...,
        from key: RedisKey,
        as type: Value.Type
    ) -> EventLoopFuture<[Value?]> {
        return self.hmget(fields, from: key, as: type)
    }

    /// Returns all the fields and values stored in a hash.
    ///
    /// See [https://redis.io/commands/hgetall](https://redis.io/commands/hgetall)
    /// - Parameter key: The key of the hash to pull from.
    /// - Returns: A key-value pair list of fields and their values.
    public func hgetall(from key: RedisKey) -> EventLoopFuture<[String: RESPValue]> {
        let args = [RESPValue(bulk: key)]
        return send(command: "HGETALL", with: args)
            .map(to: [RESPValue].self)
            .flatMapThrowing(Self._mapHashResponse)
    }

    /// Returns all the fields and values stored in a hash.
    ///
    /// See [https://redis.io/commands/hgetall](https://redis.io/commands/hgetall)
    /// - Parameters:
    ///     - key: The key of the hash to pull from.
    ///     - type: The type to convert the values to.
    /// - Returns: A key-value pair list of fields and their values. Elements that fail the `RESPValue` conversion will be `nil`.
    @inlinable
    public func hgetall<Value: RESPValueConvertible>(
        from key: RedisKey,
        as type: Value.Type
    ) -> EventLoopFuture<[String: Value?]> {
        return self.hgetall(from: key)
            .map { return $0.mapValues(Value.init(fromRESP:)) }
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
    public func hincrby<Value: FixedWidthInteger & RESPValueConvertible>(
        _ amount: Value,
        field: String,
        in key: RedisKey
    ) -> EventLoopFuture<Value> {
        return _hincr(command: "HINCRBY", amount, field, key)
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
    public func hincrbyfloat<Value: BinaryFloatingPoint & RESPValueConvertible>(
        _ amount: Value,
        field: String,
        in key: RedisKey
    ) -> EventLoopFuture<Value> {
        return _hincr(command: "HINCRBYFLOAT", amount, field, key)
    }
    
    @usableFromInline
    internal func _hincr<Value: RESPValueConvertible>(
        command: String,
        _ amount: Value,
        _ field: String,
        _ key: RedisKey
    ) -> EventLoopFuture<Value> {
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: field),
            amount.convertedToRESPValue()
        ]
        return send(command: command, with: args)
            .map()
    }
}
