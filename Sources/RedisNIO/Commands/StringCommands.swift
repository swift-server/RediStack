//===----------------------------------------------------------------------===//
//
// This source file is part of the RedisNIO open source project
//
// Copyright (c) 2019 RedisNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RedisNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIO

// MARK: Get

extension RedisClient {
    /// Get the value of a key.
    /// - Note: This operation only works with string values.
    ///     The `EventLoopFuture` will fail with a `RedisError` if the value is not a string, such as a Set.
    ///
    /// [https://redis.io/commands/get](https://redis.io/commands/get)
    /// - Parameter key: The key to fetch the value from.
    /// - Returns: The string value stored at the key provided, otherwise `nil` if the key does not exist.
    @inlinable
    public func get(_ key: String) -> EventLoopFuture<String?> {
        return send(command: "GET", with: [key])
            .map { return $0.string }
    }

    /// Gets the values of all specified keys, using `.null` to represent non-existant values.
    ///
    /// See [https://redis.io/commands/mget](https://redis.io/commands/mget)
    /// - Parameter keys: The list of keys to fetch the values from.
    /// - Returns: The values stored at the keys provided, matching the same order.
    @inlinable
    public func mget(_ keys: [String]) -> EventLoopFuture<[RESPValue]> {
        guard keys.count > 0 else { return self.eventLoop.makeSucceededFuture([]) }

        return send(command: "MGET", with: keys)
            .convertFromRESPValue()
    }
}

// MARK: Set

extension RedisClient {
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
    public func set(_ key: String, to value: RESPValueConvertible) -> EventLoopFuture<Void> {
        return send(command: "SET", with: [key, value])
            .map { _ in () }
    }

    /// Sets each key to their respective new value, overwriting existing values.
    /// - Note: Use `msetnx(_:)` if you don't want to overwrite values.
    ///
    /// See [https://redis.io/commands/mset](https://redis.io/commands/mset)
    /// - Parameter operations: The key-value list of SET operations to execute.
    /// - Returns: An `EventLoopFuture` that resolves if the operation was successful.
    @inlinable
    public func mset(_ operations: [String: RESPValueConvertible]) -> EventLoopFuture<Void> {
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
    public func msetnx(_ operations: [String: RESPValueConvertible]) -> EventLoopFuture<Bool> {
        return _mset(command: "MSETNX", operations)
            .convertFromRESPValue(to: Int.self)
            .map { return $0 == 1 }
    }

    @usableFromInline
    func _mset(
        command: String,
        _ operations: [String: RESPValueConvertible]
    ) -> EventLoopFuture<RESPValue> {
        assert(operations.count > 0, "At least 1 key-value pair should be provided.")

        let args: [RESPValueConvertible] = operations.reduce(into: [], { (result, element) in
            result.append(element.key)
            result.append(element.value)
        })

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
    @inlinable
    public func increment(_ key: String) -> EventLoopFuture<Int> {
        return send(command: "INCR", with: [key])
            .convertFromRESPValue()
    }

    /// Increments the stored value by the amount desired .
    ///
    /// See [https://redis.io/commands/incrby](https://redis.io/commands/incrby)
    /// - Parameters:
    ///     - key: The key whose value should be incremented.
    ///     - count: The amount that this value should be incremented, supporting both positive and negative values.
    /// - Returns: The new value after the operation.
    @inlinable
    public func increment(_ key: String, by count: Int) -> EventLoopFuture<Int> {
        return send(command: "INCRBY", with: [key, count])
            .convertFromRESPValue()
    }

    /// Increments the stored value by the amount desired.
    ///
    /// See [https://redis.io/commands/incrbyfloat](https://redis.io/commands/incrbyfloat)
    /// - Parameters:
    ///     - key: The key whose value should be incremented.
    ///     - count: The amount that this value should be incremented, supporting both positive and negative values.
    /// - Returns: The new value after the operation.
    @inlinable
    public func increment<T: BinaryFloatingPoint>(_ key: String, by count: T) -> EventLoopFuture<T>
        where T: RESPValueConvertible
    {
        return send(command: "INCRBYFLOAT", with: [key, count])
            .convertFromRESPValue()
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
    public func decrement(_ key: String) -> EventLoopFuture<Int> {
        return send(command: "DECR", with: [key])
            .convertFromRESPValue()
    }

    /// Decrements the stored valye by the amount desired.
    ///
    /// See [https://redis.io/commands/decrby](https://redis.io/commands/decrby)
    /// - Parameters:
    ///     - key: The key whose value should be decremented.
    ///     - count: The amount that this value should be decremented, supporting both positive and negative values.
    /// - Returns: The new value after the operation.
    public func decrement(_ key: String, by count: Int) -> EventLoopFuture<Int> {
        return send(command: "DECRBY", with: [key, count])
            .convertFromRESPValue()
    }
}
