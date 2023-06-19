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
            .tryConverting()
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

/// A condition which must hold true in order for a key to be set.
///
/// See [https://redis.io/commands/set](https://redis.io/commands/set)
public struct RedisSetCommandCondition: Hashable {
    private enum Condition: String, Hashable {
        case keyExists = "XX"
        case keyDoesNotExist = "NX"
    }

    private let condition: Condition?
    private init(_ condition: Condition?) {
        self.condition = condition
    }

    /// The `RESPValue` representation of the condition.
    @usableFromInline
    internal var commandArgument: RESPValue? {
        return self.condition.map { RESPValue(from: $0.rawValue) }
    }
}

extension RedisSetCommandCondition {
    /// No condition is required to be met in order to set the key's value.
    public static let none = RedisSetCommandCondition(.none)

    /// Only set the key if it already exists.
    ///
    /// Redis documentation refers to this as the option "XX".
    public static let keyExists = RedisSetCommandCondition(.keyExists)

    /// Only set the key if it does not already exist.
    ///
    /// Redis documentation refers to this as the option "NX".
    public static let keyDoesNotExist = RedisSetCommandCondition(.keyDoesNotExist)
}

/// The expiration to apply when setting a key.
///
/// See [https://redis.io/commands/set](https://redis.io/commands/set)
public struct RedisSetCommandExpiration: Hashable {
    private enum Expiration: Hashable {
        case keepExisting
        case seconds(Int)
        case milliseconds(Int)
    }

    private let expiration: Expiration
    private init(_ expiration: Expiration) {
        self.expiration = expiration
    }

    /// An array of `RESPValue`s representing this expiration.
    @usableFromInline
    internal func asCommandArguments() -> [RESPValue] {
        switch self.expiration {
        case .keepExisting:
            return [RESPValue(from: "KEEPTTL")]
        case .seconds(let amount):
            return [RESPValue(from: "EX"), amount.convertedToRESPValue()]
        case .milliseconds(let amount):
            return [RESPValue(from: "PX"), amount.convertedToRESPValue()]
        }
    }
}

extension RedisSetCommandExpiration {
    /// Retain the existing expiration associated with the key, if one exists.
    ///
    /// Redis documentation refers to this as "KEEPTTL".
    /// - Important: This is option is only available in Redis 6.0+. An error will be returned if this value is sent in lower versions of Redis.
    public static let keepExisting = RedisSetCommandExpiration(.keepExisting)

    /// Expire the key after the given number of seconds.
    ///
    /// Redis documentation refers to this as the option "EX".
    /// - Important: The actual amount used will be the specified value or `1`, whichever is larger.
    public static func seconds(_ amount: Int) -> RedisSetCommandExpiration {
        return RedisSetCommandExpiration(.seconds(max(amount, 1)))
    }

    /// Expire the key after the given number of milliseconds.
    ///
    /// Redis documentation refers to this as the option "PX".
    /// - Important: The actual amount used will be the specified value or `1`, whichever is larger.
    public static func milliseconds(_ amount: Int) -> RedisSetCommandExpiration {
        return RedisSetCommandExpiration(.milliseconds(max(amount, 1)))
    }
}

/// The result of a `SET` command.
public enum RedisSetCommandResult: Hashable {
    /// The command completed successfully.
    case ok

    /// The command was not performed because a condition was not met.
    ///
    /// See `RedisSetCommandCondition`.
    case conditionNotMet
}

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
            .tryConverting()
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
    ) -> EventLoopFuture<RedisSetCommandResult> {
        var args: [RESPValue] = [
            .init(from: key),
            value.convertedToRESPValue()
        ]

        if let conditionArgument = condition.commandArgument {
            args.append(conditionArgument)
        }

        if let expiration = expiration {
            args.append(contentsOf: expiration.asCommandArguments())
        }

        return self.send(command: "SET", with: args)
            .map { return $0.isNull ? .conditionNotMet : .ok }
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
    public func setnx<Value: RESPValueConvertible>(_ key: RedisKey, to value: Value) -> EventLoopFuture<Bool> {
        let args: [RESPValue] = [
            .init(from: key),
            value.convertedToRESPValue()
        ]
        return self.send(command: "SETNX", with: args)
            .tryConverting(to: Int.self)
            .map { $0 == 1 }
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
    ) -> EventLoopFuture<Void> {
        let args: [RESPValue] = [
            .init(from: key),
            .init(from: max(1, expiration)),
            value.convertedToRESPValue()
        ]
        return self.send(command: "SETEX", with: args)
            .map { _ in () }
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
    ) -> EventLoopFuture<Void> {
        let args: [RESPValue] = [
            .init(from: key),
            .init(from: max(1, expiration)),
            value.convertedToRESPValue()
        ]
        return self.send(command: "PSETEX", with: args)
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
            .tryConverting(to: Int.self)
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
            .tryConverting()
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
            .tryConverting()
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
            .tryConverting()
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
            .tryConverting()
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
            .tryConverting()
    }
}
