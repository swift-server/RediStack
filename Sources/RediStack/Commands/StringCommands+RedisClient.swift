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
    /// - Returns: The string value stored at the key provided, otherwise `nil` if the key does not exist.
    public func get(_ key: RedisKey) -> EventLoopFuture<String?> {
        return self.sendCommand(.get(key, as: String.self))
    }

    /// Get the value of a key, converting it to the desired type.
    ///
    /// [https://redis.io/commands/get](https://redis.io/commands/get)
    /// - Parameters:
    ///     - key: The key to fetch the value from.
    ///     - type: The desired type to convert the stored data to.
    /// - Returns: The converted value stored at the key provided, otherwise `nil` if the key does not exist or fails the conversion.
    @inlinable
    public func get<StoredType: RESPValueConvertible>(
        _ key: RedisKey,
        as type: StoredType.Type
    ) -> EventLoopFuture<StoredType?> {
        return self.sendCommand(.get(key, as: type))
    }

    /// Gets the values of all specified keys, using `.null` to represent non-existant values.
    ///
    /// See [https://redis.io/commands/mget](https://redis.io/commands/mget)
    /// - Parameter keys: The list of keys to fetch the values from.
    /// - Returns: The values stored at the keys provided, matching the same order.
    public func mget(_ keys: [RedisKey]) -> EventLoopFuture<[RESPValue]> {
        guard keys.count > 0 else { return self.eventLoop.makeSucceededFuture([]) }
        return self.sendCommand(.mget(keys))
    }
    
    /// Gets the values of all specified keys, using `.null` to represent non-existant values.
    ///
    /// See [https://redis.io/commands/mget](https://redis.io/commands/mget)
    /// - Parameter keys: The list of keys to fetch the values from.
    /// - Returns: The values stored at the keys provided, matching the same order.
    public func mget(_ keys: RedisKey...) -> EventLoopFuture<[RESPValue]> {
        return self.mget(keys)
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
        return self.sendCommand(.append(value, to: key))
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
        return self.sendCommand(.set(key, to: value))
            .map { _ in return () }
    }

    /// Sets each key to their respective new value, overwriting existing values.
    /// - Note: Use `msetnx(_:)` if you don't want to overwrite values.
    ///
    /// See [https://redis.io/commands/mset](https://redis.io/commands/mset)
    /// - Parameter operations: The key-value list of SET operations to execute.
    /// - Returns: An `EventLoopFuture` that resolves if the operation was successful.
    @inlinable
    public func mset<Value: RESPValueConvertible>(_ operations: [RedisKey: Value]) -> EventLoopFuture<Void> {
        return self.sendCommand(.mset(operations))
            .map { _ in return () }
    }

    /// Sets each key to their respective new value, only if all keys do not currently exist.
    /// - Note: Use `mset(_:)` if you don't care about overwriting values.
    ///
    /// See [https://redis.io/commands/msetnx](https://redis.io/commands/msetnx)
    /// - Parameter operations: The key-value list of SET operations to execute.
    /// - Returns: `true` if the operation successfully completed.
    @inlinable
    public func msetnx<Value: RESPValueConvertible>(_ operations: [RedisKey: Value]) -> EventLoopFuture<Bool> {
        return self.sendCommand(.msetnx(operations))
            .map { return $0 == 1 }
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
        return self.sendCommand(.incrby(key, amount: 1))
    }

    /// Increments the stored value by the amount desired .
    ///
    /// See [https://redis.io/commands/incrby](https://redis.io/commands/incrby)
    /// - Parameters:
    ///     - key: The key whose value should be incremented.
    ///     - amount: The amount that this value should be incremented, supporting both positive and negative values.
    /// - Returns: The new value after the operation.
    @inlinable
    public func increment<Value>(_ key: RedisKey, by amount: Value) -> EventLoopFuture<Int>
        where Value: SignedInteger & RESPValueConvertible
    {
        return self.sendCommand(.incrby(key, amount: amount))
    }

    /// Increments the stored value by the amount desired.
    ///
    /// See [https://redis.io/commands/incrbyfloat](https://redis.io/commands/incrbyfloat)
    /// - Parameters:
    ///     - key: The key whose value should be incremented.
    ///     - amount: The amount that this value should be incremented, supporting both positive and negative values.
    /// - Returns: The new value after the operation.
    @inlinable
    public func increment<Value>(_ key: RedisKey, by amount: Value) -> EventLoopFuture<Value>
        where Value: BinaryFloatingPoint & RESPValueConvertible
    {
        return self.sendCommand(.incrbyfloat(key, amount: amount))
    }
}
    
// MARK: Decrement

extension RedisClient {
    /// Decrements the stored value by 1.
    ///
    /// See [https://redis.io/commands/decr](https://redis.io/commands/decr)
    /// - Parameter key: The key whose value should be decremented.
    /// - Returns: The new value after the operation.
    public func decrement(_ key: RedisKey) -> EventLoopFuture<Int> {
        return self.sendCommand(.decr(key))
    }

    /// Decrements the stored valye by the amount desired.
    ///
    /// See [https://redis.io/commands/decrby](https://redis.io/commands/decrby)
    /// - Parameters:
    ///     - key: The key whose value should be decremented.
    ///     - amount: The amount that this value should be decremented, supporting both positive and negative values.
    /// - Returns: The new value after the operation.
    public func decrement(_ key: RedisKey, by amount: Int) -> EventLoopFuture<Int> {
        return self.sendCommand(.decrby(key, amount: amount))
    }
}
