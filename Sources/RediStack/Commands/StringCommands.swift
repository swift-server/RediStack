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
import Foundation
import NIO

// MARK: Strings

extension RedisCommand {    
    /// [APPEND](https://redis.io/commands/append)
    /// - Parameters:
    ///     - value: The value to append onto the value stored at the key.
    ///     - key: The key to use to uniquely identify this value.
    @inlinable
    public static func append<Value: RESPValueConvertible>(_ value: Value, to key: RedisKey) -> RedisCommand<Int> {
        let args: [RESPValue] = [
            .init(from: key),
            value.convertedToRESPValue()
        ]
        return .init(keyword: "APPEND", arguments: args)
    }

    /// [DECR](https://redis.io/commands/decr)
    /// - Parameter key: The key whose value should be decremented.
    public static func decr(_ key: RedisKey) -> RedisCommand<Int> {
        let args = [RESPValue(from: key)]
        return .init(keyword: "DECR", arguments: args)
    }

    /// [DECRBY](https://redis.io/commands/decrby)
    /// - Parameters:
    ///     - key: The key whose value should be decremented.
    ///     - count: The amount that this value should be decremented, supporting both positive and negative values.
    @inlinable
    public static func decrby<Value: FixedWidthInteger & RESPValueConvertible>(
        _ key: RedisKey,
        by count: Value
    ) -> RedisCommand<Value> {
        let args: [RESPValue] = [
            .init(from: key),
            .init(bulk: count)
        ]
        return .init(keyword: "DECRBY", arguments: args)
    }
    
    /// [GET](https://redis.io/commands/get)
    /// - Parameter key: The key to fetch the value from.
    public static func get(_ key: RedisKey) -> RedisCommand<RESPValue?> {
        let args = [RESPValue(from: key)]
        return .init(keyword: "GET", arguments: args) { try? $0.map() }
    }

    /// [INCR](https://redis.io/commands/incr)
    /// - Parameter key: The key whose value should be incremented.
    public static func incr(_ key: RedisKey) -> RedisCommand<Int> {
        let args = [RESPValue(from: key)]
        return .init(keyword: "INCR", arguments: args)
    }

    /// [INCRBY](https://redis.io/commands/incrby)
    /// - Parameters:
    ///     - key: The key whose value should be incremented.
    ///     - count: The amount that this value should be incremented, supporting both positive and negative values.
    @inlinable
    public static func incrby<Value: FixedWidthInteger & RESPValueConvertible>(
        _ key: RedisKey,
        by count: Value
    ) -> RedisCommand<Value> {
        let args: [RESPValue] = [
            .init(from: key),
            .init(bulk: count)
        ]
        return .init(keyword: "INCRBY", arguments: args)
    }

    /// [INCRBYFLOAT](https://redis.io/commands/incrbyfloat)
    /// - Parameters:
    ///     - key: The key whose value should be incremented.
    ///     - count: The amount that this value should be incremented, supporting both positive and negative values.
    @inlinable
    public static func incrbyfloat<Value: BinaryFloatingPoint & RESPValueConvertible>(
        _ key: RedisKey,
        by count: Value
    ) -> RedisCommand<Value> {
        let args: [RESPValue] = [
            .init(from: key),
            count.convertedToRESPValue()
        ]
        return .init(keyword: "INCRBYFLOAT", arguments: args)
    }

    /// [MGET](https://redis.io/commands/mget)
    /// - Parameter keys: The list of keys to fetch the values from.
    public static func mget(_ keys: RedisKey...) -> RedisCommand<[RESPValue?]> { .mget(keys) }

    /// [MGET](https://redis.io/commands/mget)
    /// - Parameter keys: The list of keys to fetch the values from.
    public static func mget(_ keys: [RedisKey]) -> RedisCommand<[RESPValue?]> {
        let args = keys.map(RESPValue.init(from:))
        return .init(keyword: "MGET", arguments: args) {
            // Redis will represent non-existant values as `.null`
            // we want to represent that natively in Swift with an optional
            let values = try $0.map(to: [RESPValue].self)
            return values.map { $0 == .null ? nil : $0 }
        }
    }

    /// [MSET](https://redis.io/commands/mset)
    /// - Note: Use ``msetnx(_:)`` if you don't want to overwrite values.
    /// - Parameter operations: The key-value list of SET operations to execute.
    public static func mset(_ operations: [RedisKey: RESPValueConvertible]) -> RedisCommand<Void> {
        return ._mset(keyword: "MSET", operations) { _ in }
    }

    /// [MSETNX](https://redis.io/commands/msetnx)
    /// - Note: Use ``mset(_:)`` if you don't care about overwriting values.
    /// - Parameter operations: The key-value list of SET operations to execute.
    public static func msetnx(_ operations: [RedisKey: RESPValueConvertible]) -> RedisCommand<Bool> {
        return ._mset(keyword: "MSETNX", operations) {
            let result = try $0.map(to: Int.self)
            return result == 1
        }
    }

    /// [PSETEX](https://redis.io/commands/psetex)
    /// - Invariant: The actual `expiration` used will be the given value or `1`, whichever is larger.
    /// - Parameters:
    ///     - key: The key to use to uniquely identify this value.
    ///     - value: The value to set the key to.
    ///     - expiration: The number of milliseconds after which to expire the key.
    @inlinable
    public static func psetex<Value: RESPValueConvertible>(
        _ key: RedisKey,
        to value: Value,
        expirationInMilliseconds expiration: Int
    ) -> RedisCommand<Void> {
        let args: [RESPValue] = [
            .init(from: key),
            .init(from: max(1, expiration)),
            value.convertedToRESPValue()
        ]
        return .init(keyword: "PSETEX", arguments: args)
    }

    /// [SET](https://redis.io/commands/set)
    /// - Parameters:
    ///     - key: The key to use to uniquely identify this value.
    ///     - value: The value to set the key to.
    @inlinable
    public static func set<Value: RESPValueConvertible>(_ key: RedisKey, to value: Value) -> RedisCommand<Void> {
        let args: [RESPValue] = [
            .init(from: key),
            value.convertedToRESPValue()
        ]
        return .init(keyword: "SET", arguments: args)
    }

    /// [SET](https://redis.io/commands/set)
    /// - Parameters:
    ///     - key: The key to use to uniquely identify this value.
    ///     - value: The value to set the key to.
    ///     - condition: The condition under which the key should be set.
    ///     - expiration: The expiration to use when setting the key. No expiration is set if `nil`.
    @inlinable
    public static func set<Value: RESPValueConvertible>(
        _ key: RedisKey,
        to value: Value,
        onCondition condition: RedisSetCommandCondition,
        expiration: RedisSetCommandExpiration? = nil
    ) -> RedisCommand<RedisSetCommandResult> {
        var args: [RESPValue] = [
            .init(from: key),
            value.convertedToRESPValue()
        ]

        if let arg = condition.commandArgument { args.append(arg) }
        if let e = expiration { args.append(contentsOf: e.asCommandArguments()) }

        return .init(keyword: "SET", arguments: args) { $0.isNull ? .conditionNotMet : .ok }
    }

    /// [SETEX](https://redis.io/commands/setex)
    /// - Invariant: The actual expiration used will be the specified value or `1`, whichever is larger.
    /// - Parameters:
    ///     - key: The key to use to uniquely identify this value.
    ///     - value: The value to set the key to.
    ///     - expiration: The number of seconds after which to expire the key.
    @inlinable
    public static func setex<Value: RESPValueConvertible>(
        _ key: RedisKey,
        to value: Value,
        expirationInSeconds expiration: Int
    ) -> RedisCommand<Void> {
        let args: [RESPValue] = [
            .init(from: key),
            .init(from: max(1, expiration)),
            value.convertedToRESPValue()
        ]
        return .init(keyword: "SETEX", arguments: args)
    }

    ///[SETNX](https://redis.io/commands/setnx)
    /// - Parameters:
    ///     - key: The key to use to uniquely identify this value.
    ///     - value: The value to set the key to.
    @inlinable
    public static func setnx<Value: RESPValueConvertible>(_ key: RedisKey, to value: Value) -> RedisCommand<Bool> {
        let args: [RESPValue] = [
            .init(from: key),
            value.convertedToRESPValue()
        ]
        return .init(keyword: "SETNX", arguments: args)
    }
  
  ///[STRLEN](https://redis.io/commands/strln)
  /// - Parameter key: The key to fetch the length of.
  public static func strln(_ key: RedisKey) -> RedisCommand<Int> {
    .init(keyword: "STRLEN", arguments: [.init(from: key)])
  }
}

// MARK: -

extension RedisClient {
    /// Gets the value of the given key.
    ///
    /// See ``RedisCommand/get(_:)``
    /// - Parameters:
    ///     - key: The key to fetch the value from.
    ///     - eventLoop: An optional event loop to hop to for any further chaining on the returned event loop future.
    ///     - logger: An optional logger instance to use for logs generated from this command.
    /// - Returns: A `NIO.EventLoopFuture` that resolves the value stored at the given key, otherwise `nil`.
    public func get(
        _ key: RedisKey,
        eventLoop: EventLoop? = nil,
        logger: Logger? = nil
    ) -> EventLoopFuture<RESPValue?> {
        return self.send(.get(key), eventLoop: eventLoop, logger: logger)
    }

    /// Gets the value of the given key, converting it to the desired type.
    ///
    /// See ``RedisCommand/get(_:)`
    /// - Parameters:
    ///     - key: The key to fetch the value from.
    ///     - type: The desired type to convert the stored data to.
    ///     - eventLoop: An optional event loop to hop to for any further chaining on the returned event loop future.
    ///     - logger: An optional logger instance to use for logs generated from this command.
    /// - Returns: A `NIO.EventLoopFuture` that resolves the converted value stored at the given key, otherwise `nil` if the key does not exist or fails the type conversion.
    @inlinable
    public func get<Value: RESPValueConvertible>(
        _ key: RedisKey,
        as type: Value.Type = Value.self,
        eventLoop: EventLoop? = nil,
        logger: Logger? = nil
    ) -> EventLoopFuture<Value?> {
        return self.get(key, eventLoop: eventLoop, logger: logger)
            .flatMapThrowing { $0.flatMap(Value.init(fromRESP:)) }
    }

    /// Gets the value of the given key, decoding it as a JSON data structure.
    ///
    /// See ``RedisCommand/get(_:)``
    /// - Parameters:
    ///     - key: The key to fetch the value from.
    ///     - type: The JSON type to decode to.
    ///     - decoder: The optional JSON decoder instance to use. Defaults to `.init()`.
    ///     - eventLoop: An optional event loop to hop to for any further chaining on the returned event loop future.
    ///     - logger: An optional logger instance to use for logs generated from this command.
    /// - Returns: A `NIO.EventLoopFuture` that resolves the decoded JSON value at the given key, otherwise `nil` if the key does not exist or JSON decoding fails.
    @inlinable
    public func get<D: Decodable>(
        _ key: RedisKey,
        asJSON type: D.Type = D.self,
        decoder: JSONDecoder = .init(),
        eventLoop: EventLoop? = nil,
        logger: Logger? = nil
    ) -> EventLoopFuture<D?> {
        return self.get(key, as: Data.self, eventLoop: eventLoop, logger: logger)
            .flatMapThrowing { data in
                return try data.map { try decoder.decode(D.self, from: $0) }
            }
    }

    /// Sets the value stored at the given key, overwriting the previous value.
    ///
    /// Any previous expiration set on the key is discarded if the `SET` operation was successful.
    ///
    /// See ``RedisCommand/set(_:to:)``
    /// - Important: Regardless of the type of value stored at the `key`, it will be overwritten to a "string" value.
    /// - Parameters:
    ///     - key: The key to use to uniquely identify this value in Redis.
    ///     - value: The value to set the `key` to.
    ///     - eventLoop: An optional event loop to hop to for any further chaining on the returned event loop future.
    ///     - logger: An optional logger instance to use for logs generated from this command.
    /// - Returns: A `NIO.EventLoopFuture` that resolves if the operation was successful.
    @inlinable
    public func set<Value: RESPValueConvertible>(
        _ key: RedisKey,
        to value: Value,
        eventLoop: EventLoop? = nil,
        logger: Logger? = nil
    ) -> EventLoopFuture<Void> {
        return self.send(.set(key, to: value), eventLoop: eventLoop, logger: logger)
    }

    /// Sets the value stored at the given key with options to control how to set it.
    ///
    /// See ``RedisCommand/set(_:to:onCondition:expiration:)``
    /// - Important: Regardless of the type of value stored at the `key`, it will be overwritten to a "string" value.
    /// - Parameters:
    ///     - key: The key to use to uniquely identify this value.
    ///     - value: The value to set the `key` to.
    ///     - condition: The condition under which the `key` should be set.
    ///     - expiration: The expiration to set on the `key` when setting the value. If `nil`, no expiration will be set.
    ///     - eventLoop: An optional event loop to hop to for any further chaining on the returned event loop future.
    ///     - logger: An optional logger instance to use for logs generated from this command.
    /// - Returns: A `NIO.EventLoopFuture` indicating the result of the operation; `.ok` if successful and `.conditionNotMet` if the given `condition` was not meth.
    ///
    ///     If the condition `.none` was used, then the result value will always be `.ok`.
    @inlinable
    public func set<Value: RESPValueConvertible>(
        _ key: RedisKey,
        to value: Value,
        onCondition condition: RedisSetCommandCondition,
        expiration: RedisSetCommandExpiration? = nil,
        eventLoop: EventLoop? = nil,
        logger: Logger? = nil
    ) -> EventLoopFuture<RedisSetCommandResult> {
        return self.send(.set(key, to: value, onCondition: condition, expiration: expiration), eventLoop: eventLoop, logger: logger)
    }

    /// Sets the value stored at the given key to the given value as JSON data.
    ///
    /// See ``RedisCommand/set(_:to:)``
    /// - Important: Regardless of the type of value stored at the `key`, it will be overwritten to a "string" value.
    /// - Parameters:
    ///     - key: The key to use to uniquely identify this value in Redis.
    ///     - value: The value to convert to JSON data and set the `key` to.
    ///     - encoder: The optional JSON encoder instance to use. Defaults to `.init()`.
    ///     - eventLoop: An optional event loop to hop to for any further chaining on the returned event loop future.
    ///     - logger: An optional logger instance to use for logs generated from this command.
    /// - Returns: A `NIO.EventLoopFuture` that resolves if the operation was successful.
    @inlinable
    public func set<E: Encodable>(
        _ key: RedisKey,
        toJSON value: E,
        encoder: JSONEncoder = .init(),
        eventLoop: EventLoop? = nil,
        logger: Logger? = nil
    ) -> EventLoopFuture<Void> {
        do {
            return try self.set(key, to: encoder.encode(value), eventLoop: eventLoop, logger: logger)
        } catch {
            return self.eventLoop.makeFailedFuture(error)
        }
    }

    /// Sets the value stored at the given key as JSON data with options to control how to set it.
    ///
    /// See ``RedisCommand/set(_:to:onCondition:expiration:)``
    /// - Important: Regardless of the type of value stored at the `key`, it will be overwritten to a "string" value.
    /// - Parameters:
    ///     - key: The key to use to uniquely identify this value in Redis.
    ///     - value: The value to convert to JSON data set the `key` to.
    ///     - condition: The condition under which the `key` should be set.
    ///     - expiration: The expiration to set on the `key` when setting the value. If `nil`, no expiration will be set.
    ///     - eventLoop: An optional event loop to hop to for any further chaining on the returned event loop future.
    ///     - logger: An optional logger instance to use for logs generated from this command.
    /// - Returns: A `NIO.EventLoopFuture` indicating the result of the operation; `.ok` if successful and `.conditionNotMet` if the given `condition` was not meth.
    ///
    ///     If the condition `.none` was used, then the result value will always be `.ok`.
    @inlinable
    public func set<E: Encodable>(
        _ key: RedisKey,
        toJSON value: E,
        onCondition condition: RedisSetCommandCondition,
        expiration: RedisSetCommandExpiration? = nil,
        encoder: JSONEncoder = .init(),
        eventLoop: EventLoop? = nil,
        logger: Logger? = nil
    ) -> EventLoopFuture<RedisSetCommandResult> {
        do {
            return try self.send(.set(key, to: encoder.encode(value), onCondition: condition, expiration: expiration), eventLoop: eventLoop, logger: logger)
        } catch {
            return self.eventLoop.makeFailedFuture(error)
        }
    }
}

// MARK: -

/// A condition which must hold true in order for a key to be set with the `SET` command.
///
/// See [SET](https://redis.io/commands/set)
public struct RedisSetCommandCondition: Hashable {
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

/// The expiration to apply when setting a key with the `SET` command.
///
/// See [SET](https://redis.io/commands/set)
public struct RedisSetCommandExpiration: Hashable {
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
        return .init(.seconds(max(amount, 1)))
    }

    /// Expire the key after the given number of milliseconds.
    ///
    /// Redis documentation refers to this as the option "PX".
    /// - Important: The actual amount used will be the specified value or `1`, whichever is larger.
    public static func milliseconds(_ amount: Int) -> RedisSetCommandExpiration {
        return .init(.milliseconds(max(amount, 1)))
    }
    
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

/// The result of a `SET` command.
public enum RedisSetCommandResult: Hashable {
    /// The command completed successfully.
    case ok
    /// The command was not performed because a condition was not met.
    ///
    /// See `RedisSetCommandCondition`.
    case conditionNotMet
}

// MARK: - Shared implementation

extension RedisCommand {
    fileprivate static func _mset<ResultType>(
        keyword: String,
        _ operations: [RedisKey: RESPValueConvertible],
        _ transform: @escaping (RESPValue) throws -> ResultType
    ) -> RedisCommand<ResultType> {
        assert(operations.count > 0, "at least 1 key-value pari should be provided")
        
        let args: [RESPValue ] = operations.reduce(
            into: .init(initialCapacity: operations.count * 2),
            { array, element in
                array.append(.init(from: element.key))
                array.append(element.value.convertedToRESPValue())
            }
        )
        return .init(keyword: keyword, arguments: args, mapValueToResult: transform)
    }
}
