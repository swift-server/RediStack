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

// MARK: Get

extension RedisClient {
    /// Get the value of a key.
    ///
    /// [https://redis.io/commands/get](https://redis.io/commands/get)
    /// - Parameter key: The key to fetch the value from.
    /// - Returns: The value stored at the key provided. If the key does not exist, the value will be `.null`.
    public func get(_ key: RedisKey) -> EventLoopFuture<RESPValue> {
        let args = [RESPValue(from: key)]
        return self.send(command: "GET", with: args)
    }
    
    /// Get the value of a key, converting it to the desired type.
    ///
    /// [https://redis.io/commands/get](https://redis.io/commands/get)
    /// - Parameters:
    ///     - key: The key to fetch the value from.
    ///     - type: The desired type to convert the stored data to.
    /// - Returns: The converted value stored at the key provided, otherwise `nil` if the key does not exist or fails the type conversion.
    @inlinable
    public func get<StoredType: RESPValueConvertible>(
        _ key: RedisKey,
        as type: StoredType.Type
    ) -> EventLoopFuture<StoredType?> {
        return self.get(key)
            .map { return StoredType(fromRESP: $0) }
    }

    /// Gets the values of all specified keys, using `.null` to represent non-existant values.
    ///
    /// See [https://redis.io/commands/mget](https://redis.io/commands/mget)
    /// - Parameter keys: The list of keys to fetch the values from.
    /// - Returns: The values stored at the keys provided, matching the same order.
    public func mget(_ keys: [RedisKey]) -> EventLoopFuture<[RESPValue]> {
        guard keys.count > 0 else { return self.eventLoop.makeSucceededFuture([]) }

        let args = keys.map(RESPValue.init)
        return send(command: "MGET", with: args)
            .map()
    }
    
    /// Gets the values of all specified keys, using `.null` to represent non-existant values.
    ///
    /// See [https://redis.io/commands/mget](https://redis.io/commands/mget)
    /// - Parameters:
    ///     - keys: The list of keys to fetch the values from.
    ///     - type: The type to convert the values to.
    /// - Returns: The values stored at the keys provided, matching the same order. Values that fail the `RESPValue` conversion will be `nil`.
    @inlinable
    public func mget<Value: RESPValueConvertible>(_ keys: [RedisKey], as type: Value.Type) -> EventLoopFuture<[Value?]> {
        return self.mget(keys)
            .map { return $0.map(Value.init(fromRESP:)) }
    }
    
    /// Gets the values of all specified keys, using `.null` to represent non-existant values.
    ///
    /// See [https://redis.io/commands/mget](https://redis.io/commands/mget)
    /// - Parameter keys: The list of keys to fetch the values from.
    /// - Returns: The values stored at the keys provided, matching the same order.
    public func mget(_ keys: RedisKey...) -> EventLoopFuture<[RESPValue]> {
        return self.mget(keys)
    }
    
    /// Gets the values of all specified keys, using `.null` to represent non-existant values.
    ///
    /// See [https://redis.io/commands/mget](https://redis.io/commands/mget)
    /// - Parameters:
    ///     - keys: The list of keys to fetch the values from.
    ///     - type: The type to convert the values to.
    /// - Returns: The values stored at the keys provided, matching the same order. Values that fail the `RESPValue` conversion will be `nil`.
    @inlinable
    public func mget<Value: RESPValueConvertible>(_ keys: RedisKey..., as type: Value.Type) -> EventLoopFuture<[Value?]> {
        return self.mget(keys, as: type)
    }
}

// MARK: Set

extension RedisClient {
    /// Append a value to the end of an existing entry.
    /// - Note: If the key does not exist, it is created and set as an empty string, so `APPEND` will be similar to `SET` in this special case.
    ///
    /// See [https://redis.io/commands/append](https://redis.io/commands/append)
    /// - Parameters:
    ///     - value: The value to append onto the value stored at the key.
    ///     - key: The key to use to uniquely identify this value.
    /// - Returns: The length of the key's value after appending the additional value.
    @inlinable
    public func append<Value: RESPValueConvertible>(_ value: Value, to key: RedisKey) -> EventLoopFuture<Int> {
        let args: [RESPValue] = [
            .init(from: key),
            value.convertedToRESPValue()
        ]
        return send(command: "APPEND", with: args)
            .map()
    }
    
    /// Sets the value stored in the key provided, overwriting the previous value.
    ///
    /// Any previous expiration set on the key is discarded if the SET operation was successful.
    ///
    /// - Important: Regardless of the type of value stored at the key, it will be overwritten to a string value.
    ///
    /// [https://redis.io/commands/set](https://redis.io/commands/set)
    /// - Parameters:
    ///     - key: The key to use to uniquely identify this value.
    ///     - value: The value to set the key to.
    /// - Returns: An `EventLoopFuture` that resolves if the operation was successful.
    @inlinable
    public func set<Value: RESPValueConvertible>(_ key: RedisKey, to value: Value) -> EventLoopFuture<Void> {
        let args: [RESPValue] = [
            .init(from: key),
            value.convertedToRESPValue()
        ]
        return send(command: "SET", with: args)
            .map { _ in () }
    }

    /// Sets each key to their respective new value, overwriting existing values.
    /// - Note: Use `msetnx(_:)` if you don't want to overwrite values.
    ///
    /// See [https://redis.io/commands/mset](https://redis.io/commands/mset)
    /// - Parameter operations: The key-value list of SET operations to execute.
    /// - Returns: An `EventLoopFuture` that resolves if the operation was successful.
    @inlinable
    public func mset<Value: RESPValueConvertible>(_ operations: [RedisKey: Value]) -> EventLoopFuture<Void> {
        return _mset(command: "MSET", operations)
            .map { _ in () }
    }

    /// Sets each key to their respective new value, only if all keys do not currently exist.
    /// - Note: Use `mset(_:)` if you don't care about overwriting values.
    ///
    /// See [https://redis.io/commands/msetnx](https://redis.io/commands/msetnx)
    /// - Parameter operations: The key-value list of SET operations to execute.
    /// - Returns: `true` if the operation successfully completed.
    @inlinable
    public func msetnx<Value: RESPValueConvertible>(_ operations: [RedisKey: Value]) -> EventLoopFuture<Bool> {
        return _mset(command: "MSETNX", operations)
            .map(to: Int.self)
            .map { return $0 == 1 }
    }
    
    @usableFromInline
    func _mset<Value: RESPValueConvertible>(
        command: String,
        _ operations: [RedisKey: Value]
    ) -> EventLoopFuture<RESPValue> {
        assert(operations.count > 0, "At least 1 key-value pair should be provided.")

        let args: [RESPValue] = operations.reduce(
            into: .init(initialCapacity: operations.count * 2),
            { (array, element) in
                array.append(.init(from: element.key))
                array.append(element.value.convertedToRESPValue())
            }
        )

        return send(command: command, with: args)
    }
}

// MARK: Increment

extension RedisClient {
    /// Increments the stored value by 1.
    ///
    /// See [https://redis.io/commands/incr](https://redis.io/commands/incr)
    /// - Parameter key: The key whose value should be incremented.
    /// - Returns: The new value after the operation.
    public func increment(_ key: RedisKey) -> EventLoopFuture<Int> {
        let args = [RESPValue(from: key)]
        return send(command: "INCR", with: args)
            .map()
    }

    /// Increments the stored value by the amount desired .
    ///
    /// See [https://redis.io/commands/incrby](https://redis.io/commands/incrby)
    /// - Parameters:
    ///     - key: The key whose value should be incremented.
    ///     - count: The amount that this value should be incremented, supporting both positive and negative values.
    /// - Returns: The new value after the operation.
    @inlinable
    public func increment<Value: FixedWidthInteger & RESPValueConvertible>(
        _ key: RedisKey,
        by count: Value
    ) -> EventLoopFuture<Value> {
        let args: [RESPValue] = [
            .init(from: key),
            .init(bulk: count)
        ]
        return send(command: "INCRBY", with: args)
            .map()
    }

    /// Increments the stored value by the amount desired.
    ///
    /// See [https://redis.io/commands/incrbyfloat](https://redis.io/commands/incrbyfloat)
    /// - Parameters:
    ///     - key: The key whose value should be incremented.
    ///     - count: The amount that this value should be incremented, supporting both positive and negative values.
    /// - Returns: The new value after the operation.
    @inlinable
    public func increment<Value: BinaryFloatingPoint & RESPValueConvertible>(
        _ key: RedisKey,
        by count: Value
    ) -> EventLoopFuture<Value> {
        let args: [RESPValue] = [
            .init(from: key),
            count.convertedToRESPValue()
        ]
        return send(command: "INCRBYFLOAT", with: args)
            .map()
    }
}

// MARK: Decrement

extension RedisClient {
    /// Decrements the stored value by 1.
    ///
    /// See [https://redis.io/commands/decr](https://redis.io/commands/decr)
    /// - Parameter key: The key whose value should be decremented.
    /// - Returns: The new value after the operation.
    @inlinable
    public func decrement(_ key: RedisKey) -> EventLoopFuture<Int> {
        let args = [RESPValue(from: key)]
        return send(command: "DECR", with: args)
            .map()
    }

    /// Decrements the stored valye by the amount desired.
    ///
    /// See [https://redis.io/commands/decrby](https://redis.io/commands/decrby)
    /// - Parameters:
    ///     - key: The key whose value should be decremented.
    ///     - count: The amount that this value should be decremented, supporting both positive and negative values.
    /// - Returns: The new value after the operation.
    @inlinable
    public func decrement<Value: FixedWidthInteger & RESPValueConvertible>(
        _ key: RedisKey,
        by count: Value
    ) -> EventLoopFuture<Value> {
        let args: [RESPValue] = [
            .init(from: key),
            .init(bulk: count)
        ]
        return send(command: "DECRBY", with: args)
            .map()
    }
}
