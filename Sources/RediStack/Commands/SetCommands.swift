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
    /// Gets all of the elements contained in a set.
    /// - Note: Ordering of results are stable between multiple calls of this method to the same set.
    ///
    /// Results are **UNSTABLE** in regards to the ordering of insertions through the `sadd` command and this method.
    ///
    /// See [https://redis.io/commands/smembers](https://redis.io/commands/smembers)
    /// - Parameter key: The key of the set.
    public static func smembers(of key: RedisKey) -> NewRedisCommand<[RESPValue]> {
        let args = [RESPValue(bulk: key)]
        return .init(keyword: "SMEMBERS", arguments: args)
    }

    /// Checks if the element is included in a set.
    ///
    /// See [https://redis.io/commands/sismember](https://redis.io/commands/sismember)
    /// - Parameters:
    ///     - element: The element to look for in the set.
    ///     - key: The key of the set to look in.
    @inlinable
    public static func sismember<Value: RESPValueConvertible>(_ element: Value, of key: RedisKey) -> NewRedisCommand<Int> {
        let args: [RESPValue] = [
            .init(bulk: key),
            element.convertedToRESPValue()
        ]
        return .init(keyword: "SISMEMBER", arguments: args)
    }

    /// Gets the total count of elements within a set.
    ///
    /// See [https://redis.io/commands/scard](https://redis.io/commands/scard)
    /// - Parameter key: The key of the set.
    public static func scard(of key: RedisKey) -> NewRedisCommand<Int> {
        let args = [RESPValue(bulk: key)]
        return .init(keyword: "SCARD", arguments: args)
    }

    /// Adds elements to a set.
    ///
    /// See [https://redis.io/commands/sadd](https://redis.io/commands/sadd)
    /// - Parameters:
    ///     - elements: The values to add to the set.
    ///     - key: The key of the set to insert into.
    @inlinable
    public static func sadd<Value: RESPValueConvertible>(_ elements: [Value], to key: RedisKey) -> NewRedisCommand<Int> {
        var args: [RESPValue] = [.init(bulk: key)]
        args.append(convertingContentsOf: elements)
        return .init(keyword: "SADD", arguments: args)
    }

    /// Removes elements from a set.
    ///
    /// See [https://redis.io/commands/srem](https://redis.io/commands/srem)
    /// - Parameters:
    ///     - elements: The values to remove from the set.
    ///     - key: The key of the set to remove from.
    @inlinable
    public static func srem<Value: RESPValueConvertible>(_ elements: [Value], from key: RedisKey) -> NewRedisCommand<Int> {
        var args: [RESPValue] = [.init(bulk: key)]
        args.append(convertingContentsOf: elements)
        return .init(keyword: "SREM", arguments: args)
    }

    /// Randomly selects and removes one or more elements in a set.
    ///
    /// See [https://redis.io/commands/spop](https://redis.io/commands/spop)
    /// - Parameters:
    ///     - key: The key of the set.
    ///     - count: The max number of elements to pop from the set.
    public static func spop(from key: RedisKey, max count: Int = 1) -> NewRedisCommand<[RESPValue]> {
        assert(count >= 0, "A negative max count is nonsense.")
        
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: count)
        ]
        return .init(keyword: "SPOP", arguments: args)
    }

    /// Randomly selects one or more elements in a set.
    ///
    /// See [https://redis.io/commands/srandmember](https://redis.io/commands/srandmember)
    /// - Parameters:
    ///     - key: The key of the set.
    ///     - count: The max number of elements to select from the set.
    public static func srandmember(from key: RedisKey, max count: Int = 1) -> NewRedisCommand<[RESPValue]> {
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: count)
        ]
        return .init(keyword: "SRANDMEMBER", arguments: args)
    }

    /// Moves an element from one set to another.
    ///
    /// See [https://redis.io/commands/smove](https://redis.io/commands/smove)
    /// - Parameters:
    ///     - element: The value to move from the source.
    ///     - sourceKey: The key of the source set.
    ///     - destKey: The key of the destination set.
    @inlinable
    public static func smove<Value: RESPValueConvertible>(
        _ element: Value,
        from sourceKey: RedisKey,
        to destKey: RedisKey
    ) -> NewRedisCommand<Int> {
        let args: [RESPValue] = [
            .init(bulk: sourceKey),
            .init(bulk: destKey),
            element.convertedToRESPValue()
        ]
        return .init(keyword: "SMOVE", arguments: args)
    }

    /// Incrementally iterates over all values in a set.
    ///
    /// See [https://redis.io/commands/sscan](https://redis.io/commands/sscan)
    /// - Parameters:
    ///     - key: The key of the set.
    ///     - position: The position to start the scan from.
    ///     - count: The number of elements to advance by. Redis default is 10.
    ///     - match: A glob-style pattern to filter values to be selected from the result set.
    public static func sscan(
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
        return .init(keyword: "SSCAN", arguments: args)
    }
}

// MARK: Diff

extension NewRedisCommand {
    /// Calculates the difference between two or more sets.
    ///
    /// See [https://redis.io/commands/sdiff](https://redis.io/commands/sdiff)
    /// - Parameter keys: The source sets to calculate the difference of.
    public static func sdiff(of keys: [RedisKey]) -> NewRedisCommand<[RESPValue]> {
        let args = keys.map(RESPValue.init)
        return .init(keyword: "SDIFF", arguments: args)
    }

    /// Calculates the difference between two or more sets and stores the result.
    /// - Important: If the destination key already exists, it is overwritten.
    ///
    /// See [https://redis.io/commands/sdiffstore](https://redis.io/commands/sdiffstore)
    /// - Parameters:
    ///     - destination: The key of the new set from the result.
    ///     - sources: The list of source sets to calculate the difference of.
    public static func sdiffstore(as destination: RedisKey, sources keys: [RedisKey]) -> NewRedisCommand<Int> {
        assert(keys.count > 0, "At least 1 key should be provided.")

        var args: [RESPValue] = [.init(bulk: destination)]
        args.append(convertingContentsOf: keys)
        
        return .init(keyword: "SDIFFSTORE", arguments: args)
    }
}

// MARK: Intersect

extension NewRedisCommand {
    /// Calculates the intersection of two or more sets.
    ///
    /// See [https://redis.io/commands/sinter](https://redis.io/commands/sinter)
    /// - Parameter keys: The source sets to calculate the intersection of.
    public static func sinter(of keys: [RedisKey]) -> NewRedisCommand<[RESPValue]> {
        let args = keys.map(RESPValue.init)
        return .init(keyword: "SINTER", arguments: args)
    }

    /// Calculates the intersetion of two or more sets and stores the result.
    /// - Important: If the destination key already exists, it is overwritten.
    ///
    /// See [https://redis.io/commands/sinterstore](https://redis.io/commands/sinterstore)
    /// - Parameters:
    ///     - destination: The key of the new set from the result.
    ///     - sources: A list of source sets to calculate the intersection of.
    public static func sinterstore(as destination: RedisKey, sources keys: [RedisKey]) -> NewRedisCommand<Int> {
        assert(keys.count > 0, "At least 1 key should be provided.")

        var args: [RESPValue] = [.init(bulk: destination)]
        args.append(convertingContentsOf: keys)
        
        return .init(keyword: "SINTERSTORE", arguments: args)
    }
}

// MARK: Union

extension NewRedisCommand {
    /// Calculates the union of two or more sets.
    ///
    /// See [https://redis.io/commands/sunion](https://redis.io/commands/sunion)
    /// - Parameter keys: The source sets to calculate the union of.
    public static func sunion(of keys: [RedisKey]) -> NewRedisCommand<[RESPValue]> {
        let args = keys.map(RESPValue.init)
        return .init(keyword: "SUNION", arguments: args)
    }

    /// Calculates the union of two or more sets and stores the result.
    /// - Important: If the destination key already exists, it is overwritten.
    ///
    /// See [https://redis.io/commands/sunionstore](https://redis.io/commands/sunionstore)
    /// - Parameters:
    ///     - destination: The key of the new set from the result.
    ///     - sources: A list of source sets to calculate the union of.
    public static func sunionstore(as destination: RedisKey, sources keys: [RedisKey]) -> NewRedisCommand<Int> {
        assert(keys.count > 0, "At least 1 key should be provided.")

        var args: [RESPValue] = [.init(bulk: destination)]
        args.append(convertingContentsOf: keys)
        
        return .init(keyword: "SUNIONSTORE", arguments: args)
    }
}
