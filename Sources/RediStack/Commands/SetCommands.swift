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

// MARK: Sets

extension RedisCommand {
    /// [SADD](https://redis.io/commands/sadd)
    /// - Parameters:
    ///     - elements: The values to add to the set.
    ///     - key: The key of the set to insert into.
    @inlinable
    public static func sadd<Value: RESPValueConvertible>(_ elements: [Value], to key: RedisKey) -> RedisCommand<Int> {
        assert(elements.count > 0, "at least 1 element should be provided")

        var args = [RESPValue(from: key)]
        args.append(convertingContentsOf: elements)
        
        return .init(keyword: "SADD", arguments: args)
    }

    /// [SADD](https://redis.io/commands/sadd)
    /// - Parameters:
    ///     - elements: The values to add to the set.
    ///     - key: The key of the set to insert into.
    @inlinable
    public static func sadd<Value: RESPValueConvertible>(_ elements: Value..., to key: RedisKey) -> RedisCommand<Int> {
        return .sadd(elements, to: key)
    }

    /// [SCARD](https://redis.io/commands/scard)
    /// - Parameter key: The key of the set.
    public static func scard(of key: RedisKey) -> RedisCommand<Int> {
        let args = [RESPValue(from: key)]
        return .init(keyword: "SCARD", arguments: args)
    }

    /// [SDIFF](https://redis.io/commands/sdiff)
    /// - Parameter keys: The source sets to calculate the difference of.
    public static func sdiff(of keys: [RedisKey]) -> RedisCommand<[RESPValue]> {
        assert(!keys.isEmpty, "at least 1 key should be provided")

        let args = keys.map(RESPValue.init(from:))
        return .init(keyword: "SDIFF", arguments: args)
    }

    /// [SDIFF](https://redis.io/commands/sdiff)
    /// - Parameter keys: The source sets to calculate the difference of.
    public static func sdiff(of keys: RedisKey...) -> RedisCommand<[RESPValue]> { .sdiff(of: keys) }

    /// [SDIFFSTORE](https://redis.io/commands/sdiffstore)
    /// - Warning: If the `destination` key already exists, its value will be overwritten.
    /// - Parameters:
    ///     - destination: The key of the new set from the result.
    ///     - sources: The list of source sets to calculate the difference of.
    public static func sdiffstore(as destination: RedisKey, sources keys: [RedisKey]) -> RedisCommand<Int> {
        assert(!keys.isEmpty, "at least 1 key should be provided")

        var args = [RESPValue(from: destination)]
        args.append(convertingContentsOf: keys)

        return .init(keyword: "SDIFFSTORE", arguments: args)
    }

    /// [SINTER](https://redis.io/commands/sinter)
    /// - Parameter keys: The source sets to calculate the intersection of.
    public static func sinter(of keys: [RedisKey]) -> RedisCommand<[RESPValue]> {
        assert(!keys.isEmpty, "at least 1 key should be provided")

        let args = keys.map(RESPValue.init(from:))
        return .init(keyword: "SINTER", arguments: args)
    }

    /// [SINTER](https://redis.io/commands/sinter)
    /// - Parameter keys: The source sets to calculate the intersection of.
    public static func sinter(of keys: RedisKey...) -> RedisCommand<[RESPValue]> { .sinter(of: keys) }

    /// [SINTERSTORE](https://redis.io/commands/sinterstore)
    /// - Warning: If the `destination` key already exists, its value will be overwritten.
    /// - Parameters:
    ///     - destination: The key of the new set from the result.
    ///     - sources: A list of source sets to calculate the intersection of.
    public static func sinterstore(as destination: RedisKey, sources keys: [RedisKey]) -> RedisCommand<Int> {
        assert(!keys.isEmpty, "at least 1 key should be provided")

        var args = [RESPValue(from: destination)]
        args.append(convertingContentsOf: keys)
        
        return .init(keyword: "SINTERSTORE", arguments: args)
    }

    /// [SISMEMBER](https://redis.io/commands/sismember)
    /// - Parameters:
    ///     - element: The element to look for in the set.
    ///     - key: The key of the set to look in.
    @inlinable
    public static func sismember<Value: RESPValueConvertible>(_ element: Value, of key: RedisKey) -> RedisCommand<Bool> {
        let args: [RESPValue] = [
            .init(from: key),
            element.convertedToRESPValue()
        ]
        return .init(keyword: "SISMEMBER", arguments: args)
    }

    /// [SMEMBERS](https://redis.io/commands/smembers)
    /// - Note: Ordering of results are stable between multiple calls of this method to the same set.
    ///
    /// Results are **UNSTABLE** in regards to the ordering of insertions through the `sadd` command and this method.
    /// - Parameter key: The key of the set.
    public static func smembers(of key: RedisKey) -> RedisCommand<[RESPValue]> {
        let args = [RESPValue(from: key)]
        return .init(keyword: "SMEMBERS", arguments: args)
    }

    /// [SMOVE](https://redis.io/commands/smove)
    /// - Parameters:
    ///     - element: The value to move from the source.
    ///     - sourceKey: The key of the source set.
    ///     - destKey: The key of the destination set.
    @inlinable
    public static func smove<Value: RESPValueConvertible>(
        _ element: Value,
        from sourceKey: RedisKey,
        to destKey: RedisKey
    ) -> RedisCommand<Bool> {
        assert(sourceKey != destKey, "same key was provided for a move operation")

        let args: [RESPValue] = [
            .init(from: sourceKey),
            .init(from: destKey),
            element.convertedToRESPValue()
        ]
        return .init(keyword: "SMOVE", arguments: args)
    }

    /// [SPOP](https://redis.io/commands/spop)
    /// - Parameters:
    ///     - key: The key of the set.
    ///     - count: The max number of elements to pop from the set.
    public static func spop(from key: RedisKey, max count: Int = 1) -> RedisCommand<[RESPValue]> {
        assert(count >= 0, "a negative max count is nonsense")

        let args: [RESPValue] = [
            .init(from: key),
            .init(bulk: count)
        ]
        return .init(keyword: "SPOP", arguments: args)
    }

    /// [SRANDMEMBER](https://redis.io/commands/srandmember)
    ///
    /// Example usage:
    /// ```swift
    /// // pull just 1 random element
    /// client.send(.srandmember(from: "my_key"))
    ///
    /// // pulls up to 3 elements, allowing duplicates
    /// client.send(.srandmember(from: "my_key", max: -3))
    ///
    /// // pulls up to 3 unique elements
    /// client.send(.srandmember(from: "my_key", max: 3))
    /// ```
    /// - Parameters:
    ///     - key: The key of the set.
    ///     - count: The max number of elements to select from the set.
    public static func srandmember(from key: RedisKey, max count: Int = 1) -> RedisCommand<[RESPValue]> {
        let args: [RESPValue] = [
            .init(from: key),
            .init(bulk: count)
        ]
        return .init(keyword: "SRANDMEMBER", arguments: args)
    }

    /// [SREM](https://redis.io/commands/srem)
    /// - Parameters:
    ///     - elements: The values to remove from the set.
    ///     - key: The key of the set to remove from.
    @inlinable
    public static func srem<Value: RESPValueConvertible>(_ elements: [Value], from key: RedisKey) -> RedisCommand<Int> {
        var args: [RESPValue] = [.init(from: key)]
        args.append(convertingContentsOf: elements)
        return .init(keyword: "SREM", arguments: args)
    }

    /// [SREM](https://redis.io/commands/srem)
    /// - Parameters:
    ///     - elements: The values to remove from the set.
    ///     - key: The key of the set to remove from.
    @inlinable
    public static func srem<Value: RESPValueConvertible>(_ elements: Value..., from key: RedisKey) -> RedisCommand<Int> {
        return .srem(elements, from: key)
    }

    /// [SUNION](https://redis.io/commands/sunion)
    /// - Parameter keys: The source sets to calculate the union of.
    public static func sunion(of keys: [RedisKey]) -> RedisCommand<[RESPValue]> {
        let args = keys.map(RESPValue.init(from:))
        return .init(keyword: "SUNION", arguments: args)
    }

    /// [SUNION](https://redis.io/commands/sunion)
    /// - Parameter keys: The source sets to calculate the union of.
    public static func sunion(of keys: RedisKey...) -> RedisCommand<[RESPValue]> { .sunion(of: keys) }

    /// [SUNIONSTORE](https://redis.io/commands/sunionstore)
    /// - Parameters:
    ///     - destination: The key of the new set from the result.
    ///     - sources: A list of source sets to calculate the union of.
    public static func sunionstore(as destination: RedisKey, sources keys: [RedisKey]) -> RedisCommand<Int> {
        assert(!keys.isEmpty, "at least 1 key should be provided")

        var args = [RESPValue(from: destination)]
        args.append(convertingContentsOf: keys)

        return .init(keyword: "SUNIONSTORE", arguments: args)
    }

    /// [SSCAN](https://redis.io/commands/sscan)
    /// - Parameters:
    ///     - key: The key of the set.
    ///     - position: The position to start the scan from.
    ///     - count: The number of elements to advance by. Redis default is 10.
    ///     - match: A glob-style pattern to filter values to be selected from the result set.
    public static func sscan(
        _ key: RedisKey,
        startingFrom position: Int = 0,
        matching match: String? = nil,
        count: Int? = nil
    ) -> RedisCommand<(Int, [RESPValue])> {
        return ._scan(keyword: "SSCAN", key, position, match, count, { try $0.map() })
    }
}

// MARK: -

extension RedisClient {
    /// Incrementally iterates over all values in a set.
    ///
    /// See ``RedisCommand/sscan(_:startingFrom:matching:count:)``
    /// - Parameters:
    ///     - key: The key of the set.
    ///     - position: The position to start the scan from.
    ///     - count: The number of elements to advance by. Redis default is 10.
    ///     - match: A glob-style pattern to filter values to be selected from the result set.
    ///     - eventLoop: An optional event loop to hop to for any further chaining on the returned event loop future.
    ///     - logger: An optional logger instance to use for logs generated from this command.
    /// - Returns: A `NIO.EventLoopFuture` that resolves a cursor position for additional scans, with a limited collection of values that were iterated over.
    public func scanSetValues(
        in key: RedisKey,
        startingFrom position: Int = 0,
        matching match: String? = nil,
        count: Int? = nil,
        eventLoop: EventLoop? = nil,
        logger: Logger? = nil
    ) -> EventLoopFuture<(Int, [RESPValue])> {
        return self.send(.sscan(key, startingFrom: position, matching: match, count: count), eventLoop: eventLoop, logger: logger)
    }
}
