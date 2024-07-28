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

import NIOCore

// MARK: Get

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension RedisClient {
    /// Get the value of a key.
    ///
    /// [https://redis.io/commands/get](https://redis.io/commands/get)
    /// - Parameter key: The key to fetch the value from.
    /// - Returns: The value stored at the key provided. If the key does not exist, the value will be `.null`.
    public func get(_ key: RedisKey) async throws -> RESPValue {
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
    ) async throws -> StoredType? {
    }

    /// Gets the values of all specified keys, using `.null` to represent non-existant values.
    ///
    /// See [https://redis.io/commands/mget](https://redis.io/commands/mget)
    /// - Parameter keys: The list of keys to fetch the values from.
    /// - Returns: The values stored at the keys provided, matching the same order.
    public func mget(_ keys: [RedisKey]) async throws -> [RESPValue] {
    }

    /// Gets the values of all specified keys, using `.null` to represent non-existant values.
    ///
    /// See [https://redis.io/commands/mget](https://redis.io/commands/mget)
    /// - Parameters:
    ///     - keys: The list of keys to fetch the values from.
    ///     - type: The type to convert the values to.
    /// - Returns: The values stored at the keys provided, matching the same order. Values that fail the `RESPValue` conversion will be `nil`.
    @inlinable
    public func mget<Value: RESPValueConvertible>(_ keys: [RedisKey], as type: Value.Type) async throws -> [Value?] {
    }

    /// Gets the values of all specified keys, using `.null` to represent non-existant values.
    ///
    /// See [https://redis.io/commands/mget](https://redis.io/commands/mget)
    /// - Parameter keys: The list of keys to fetch the values from.
    /// - Returns: The values stored at the keys provided, matching the same order.
    public func mget(_ keys: RedisKey...) async throws -> [RESPValue] {
    }

    /// Gets the values of all specified keys, using `.null` to represent non-existant values.
    ///
    /// See [https://redis.io/commands/mget](https://redis.io/commands/mget)
    /// - Parameters:
    ///     - keys: The list of keys to fetch the values from.
    ///     - type: The type to convert the values to.
    /// - Returns: The values stored at the keys provided, matching the same order. Values that fail the `RESPValue` conversion will be `nil`.
    @inlinable
    public func mget<Value: RESPValueConvertible>(_ keys: RedisKey..., as type: Value.Type) async throws -> [Value?] {
    }
}

// MARK: Set

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
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
    public func append<Value: RESPValueConvertible>(_ value: Value, to key: RedisKey) async throws -> Int {
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
    public func set<Value: RESPValueConvertible>(_ key: RedisKey, to value: Value) async throws {
    }

    /// Sets the key to the provided value with options to control how it is set.
    ///
    /// [https://redis.io/commands/set](https://redis.io/commands/set)
    /// - Important: Regardless of the type of data stored at the key, it will be overwritten to a "string" data type.
    ///
    ///   ie. If the key is a reference to a Sorted Set, its value will be overwritten to be a "string" data type.
    ///
    /// - Parameters:
    ///     - key: The key to use to uniquely identify this value.
    ///     - value: The value to set the key to.
    ///     - condition: The condition under which the key should be set.
    ///     - expiration: The expiration to use when setting the key. No expiration is set if `nil`.
    /// - Returns: A `NIO.EventLoopFuture` indicating the result of the operation;
    ///     `.ok` if the operation was successful and `.conditionNotMet` if the specified `condition` was not met.
    ///
    ///     If the condition `.none` was used, then the result value will always be `.ok`.
    public func set<Value: RESPValueConvertible>(
        _ key: RedisKey,
        to value: Value,
        onCondition condition: RedisSetCommandCondition,
        expiration: RedisSetCommandExpiration? = nil
    ) async throws -> RedisSetCommandResult {
    }

    /// Sets the key to the provided value if the key does not exist.
    ///
    /// [https://redis.io/commands/setnx](https://redis.io/commands/setnx)
    /// - Important: Regardless of the type of data stored at the key, it will be overwritten to a "string" data type.
    ///
    /// ie. If the key is a reference to a Sorted Set, its value will be overwritten to be a "string" data type.
    /// - Parameters:
    ///     - key: The key to use to uniquely identify this value.
    ///     - value: The value to set the key to.
    /// - Returns: `true` if the operation successfully completed.
    @inlinable
    public func setnx<Value: RESPValueConvertible>(_ key: RedisKey, to value: Value) async throws -> Bool {
    }

    /// Sets a key to the provided value and an expiration timeout in seconds.
    ///
    /// See [https://redis.io/commands/setex](https://redis.io/commands/setex)
    /// - Important: Regardless of the type of data stored at the key, it will be overwritten to a "string" data type.
    ///
    /// ie. If the key is a reference to a Sorted Set, its value will be overwritten to be a "string" data type.
    /// - Important: The actual expiration used will be the specified value or `1`, whichever is larger.
    /// - Parameters:
    ///     - key: The key to use to uniquely identify this value.
    ///     - value: The value to set the key to.
    ///     - expiration: The number of seconds after which to expire the key.
    /// - Returns: A `NIO.EventLoopFuture` that resolves if the operation was successful.
    @inlinable
    public func setex<Value: RESPValueConvertible>(
        _ key: RedisKey,
        to value: Value,
        expirationInSeconds expiration: Int
    ) async throws {
    }

    /// Sets a key to the provided value and an expiration timeout in milliseconds.
    ///
    /// See [https://redis.io/commands/psetex](https://redis.io/commands/psetex)
    /// - Important: Regardless of the type of data stored at the key, it will be overwritten to a "string" data type.
    ///
    /// ie. If the key is a reference to a Sorted Set, its value will be overwritten to be a "string" data type.
    /// - Important: The actual expiration used will be the specified value or `1`, whichever is larger.
    /// - Parameters:
    ///     - key: The key to use to uniquely identify this value.
    ///     - value: The value to set the key to.
    ///     - expiration: The number of milliseconds after which to expire the key.
    /// - Returns: A `NIO.EventLoopFuture` that resolves if the operation was successful.
    @inlinable
    public func psetex<Value: RESPValueConvertible>(
        _ key: RedisKey,
        to value: Value,
        expirationInMilliseconds expiration: Int
    ) async throws {
    }

    /// Sets each key to their respective new value, overwriting existing values.
    /// - Note: Use `msetnx(_:)` if you don't want to overwrite values.
    ///
    /// See [https://redis.io/commands/mset](https://redis.io/commands/mset)
    /// - Parameter operations: The key-value list of SET operations to execute.
    /// - Returns: An `EventLoopFuture` that resolves if the operation was successful.
    @inlinable
    public func mset<Value: RESPValueConvertible>(_ operations: [RedisKey: Value]) async throws {
    }

    /// Sets each key to their respective new value, only if all keys do not currently exist.
    /// - Note: Use `mset(_:)` if you don't care about overwriting values.
    ///
    /// See [https://redis.io/commands/msetnx](https://redis.io/commands/msetnx)
    /// - Parameter operations: The key-value list of SET operations to execute.
    /// - Returns: `true` if the operation successfully completed.
    @inlinable
    public func msetnx<Value: RESPValueConvertible>(_ operations: [RedisKey: Value]) async throws -> Bool {
    }
}

// MARK: Increment

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension RedisClient {
    /// Increments the stored value by 1.
    ///
    /// See [https://redis.io/commands/incr](https://redis.io/commands/incr)
    /// - Parameter key: The key whose value should be incremented.
    /// - Returns: The new value after the operation.
    public func increment(_ key: RedisKey) async throws -> Int {
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
    ) async throws -> Value {
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
    ) async throws -> Value {
    }
}

// MARK: Decrement

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension RedisClient {
    /// Decrements the stored value by 1.
    ///
    /// See [https://redis.io/commands/decr](https://redis.io/commands/decr)
    /// - Parameter key: The key whose value should be decremented.
    /// - Returns: The new value after the operation.
    @inlinable
    public func decrement(_ key: RedisKey) async throws -> Int {
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
    ) async throws -> Value {
    }
}
