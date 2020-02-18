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

import struct NIO.TimeAmount

// MARK: Zadd

extension NewRedisCommand {
    /// Adds elements to a sorted set, assigning their score to the values provided.
    ///
    /// See [https://redis.io/commands/zadd](https://redis.io/commands/zadd)
    /// - Parameters:
    ///     - elements: A list of elements and their score to add to the sorted set.
    ///     - key: The key of the sorted set.
    ///     - insertBehavior: The desired behavior of handling new and existing elements in the SortedSet.
    ///     - returnBehavior: The desired behavior of what the return value should represent.
    @inlinable
    public static func zadd<Value: RESPValueConvertible>(
        _ elements: [(element: Value, score: Double)],
        to key: RedisKey,
        inserting insertBehavior: RedisZaddInsertBehavior = .allElements,
        returning returnBehavior: RedisZaddReturnBehavior = .insertedElementsCount
    ) -> NewRedisCommand<Int> {
        var args: [RESPValue] = [.init(bulk: key)]
        
        args.append(convertingContentsOf: [insertBehavior.rawValue, returnBehavior.rawValue])
        args.add(contentsOf: elements, overestimatedCountBeingAdded: elements.count * 2) { (array, next) in
            array.append(.init(bulk: next.score.description))
            array.append(next.element.convertedToRESPValue())
        }

        return .init(keyword: "ZADD", arguments: args)
    }
}

// MARK: General

extension NewRedisCommand {
    /// Gets the number of elements in a sorted set.
    ///
    /// See [https://redis.io/commands/zcard](https://redis.io/commands/zcard)
    /// - Parameter key: The key of the sorted set.
    public static func zcard(of key: RedisKey) -> NewRedisCommand<Int> {
        let args = [RESPValue(bulk: key)]
        return .init(keyword: "ZCARD", arguments: args)
    }

    /// Gets the score of the specified element in a stored set.
    ///
    /// See [https://redis.io/commands/zscore](https://redis.io/commands/zscore)
    /// - Parameters:
    ///     - element: The element in the sorted set to get the score for.
    ///     - key: The key of the sorted set.
    @inlinable
    public static func zscore<Value: RESPValueConvertible>(of element: Value, in key: RedisKey) -> NewRedisCommand<Double?> {
        let args: [RESPValue] = [
            .init(bulk: key),
            element.convertedToRESPValue()
        ]
        return .init(keyword: "ZSCORE", arguments: args)
    }

    /// Incrementally iterates over all elements in a sorted set.
    ///
    /// See [https://redis.io/commands/zscan](https://redis.io/commands/zscan)
    /// - Parameters:
    ///     - key: The key identifying the sorted set.
    ///     - position: The position to start the scan from.
    ///     - count: The number of elements to advance by. Redis default is 10.
    ///     - match: A glob-style pattern to filter values to be selected from the result set.
    public static func zscan(
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
        return .init(keyword: "ZSCAN", arguments: args)
    }
}

// MARK: Rank

extension NewRedisCommand {
    /// Returns the rank (index) of the specified element in a sorted set.
    /// - Note: This treats the ordered set as ordered from low to high.
    /// For the inverse, see `zrevrank(of:in:)`.
    ///
    /// See [https://redis.io/commands/zrank](https://redis.io/commands/zrank)
    /// - Parameters:
    ///     - element: The element in the sorted set to search for.
    ///     - key: The key of the sorted set to search.
    @inlinable
    public static func zrank<Value: RESPValueConvertible>(of element: Value, in key: RedisKey) -> NewRedisCommand<Int?> {
        let args: [RESPValue] = [
            .init(bulk: key),
            element.convertedToRESPValue()
        ]
        return .init(keyword: "ZRANK", arguments: args)
    }

    /// Returns the rank (index) of the specified element in a sorted set.
    /// - Note: This treats the ordered set as ordered from high to low.
    /// For the inverse, see `zrank(of:in:)`.
    ///
    /// See [https://redis.io/commands/zrevrank](https://redis.io/commands/zrevrank)
    /// - Parameters:
    ///     - element: The element in the sorted set to search for.
    ///     - key: The key of the sorted set to search.
    @inlinable
    public static func zrevrank<Value: RESPValueConvertible>(of element: Value, in key: RedisKey) -> NewRedisCommand<Int?> {
        let args: [RESPValue] = [
            .init(bulk: key),
            element.convertedToRESPValue()
        ]
        return .init(keyword: "ZREVRANK", arguments: args)
    }
}

// MARK: Count

extension NewRedisCommand {
    /// Returns the count of elements in a SortedSet with a score within the range specified (inclusive by default).
    ///
    /// See `RedisZScoreBound` and [https://redis.io/commands/zcount](https://redis.io/commands/zcount)
    /// - Parameters:
    ///     - key: The key of the SortedSet that will be counted.
    ///     - range: The min and max score bounds that an element should have in order to be counted.
    public static func zcount(
        of key: RedisKey,
        withScoresBetween range: (min: RedisZScoreBound, max: RedisZScoreBound)
    ) -> NewRedisCommand<Int> {
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: range.min.description),
            .init(bulk: range.max.description)
        ]
        return .init(keyword: "ZCOUNT", arguments: args)
    }
}

// MARK: Lexiographical Count

extension NewRedisCommand {
    /// Returns the count of elements in a SortedSet whose lexiographical values are between the range specified.
    ///
    /// See `RedisZLexBound` and [https://redis.io/commands/zlexcount](https://redis.io/commands/zlexcount)
    /// - Warning: This assumes all elements in the SortedSet have the same score. If not, the returned elements are unspecified.
    /// - Parameters:
    ///     - key: The key of the SortedSet that will be counted.
    ///     - range: The min and max value bounds that an element should have in order to be counted.
    @inlinable
    public static func zlexcount<Value: CustomStringConvertible>(
        of key: RedisKey,
        withValuesBetween range: (min: RedisZLexBound<Value>, max: RedisZLexBound<Value>)
    ) -> NewRedisCommand<Int> {
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: range.min.description),
            .init(bulk: range.max.description)
        ]
        return .init(keyword: "ZLEXCOUNT", arguments: args)
    }
}

// MARK: Pop

extension NewRedisCommand {
    /// Removes elements from a sorted set with the lowest scores.
    ///
    /// See [https://redis.io/commands/zpopmin](https://redis.io/commands/zpopmin)
    /// - Parameters:
    ///     - key: The key identifying the sorted set in Redis.
    ///     - count: The max number of elements to pop from the set.
    public static func zpopmin(from key: RedisKey, max count: Int) -> NewRedisCommand<[RESPValue]> {
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: count)
        ]
        return .init(keyword: "ZPOPMIN", arguments: args)
    }

    /// Removes elements from a sorted set with the highest scores.
    ///
    /// See [https://redis.io/commands/zpopmax](https://redis.io/commands/zpopmax)
    /// - Parameters:
    ///     - key: The key identifying the sorted set in Redis.
    ///     - count: The max number of elements to pop from the set.
    public static func zpopmax(from key: RedisKey, max count: Int) -> NewRedisCommand<[RESPValue]> {
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: count)
        ]
        return .init(keyword: "ZPOPMAX", arguments: args)
    }

}

// MARK: Blocking Pop

extension NewRedisCommand {
    /// Removes the element from a sorted set with the lowest score, blocking until an element is
    /// available.
    ///
    /// - Important:
    ///     This will block a connection from completing further commands until an element
    ///     is available to pop from the group of sets.
    ///
    ///     It is **highly** recommended to set a reasonable `timeout`
    ///     or to use the non-blocking `zpopmin` method where possible.
    ///
    /// See [https://redis.io/commands/bzpopmin](https://redis.io/commands/bzpopmin)
    /// - Parameters:
    ///     - keys: A list of sorted set keys in Redis.
    ///     - timeout: The max time to wait for a value to use. `0`seconds means to wait indefinitely.
    public static func bzpopmin(from keys: [RedisKey], timeout: TimeAmount = .seconds(0)) -> NewRedisCommand<[RESPValue]?> {
        var args = keys.map(RESPValue.init)
        args.append(.init(bulk: timeout.seconds))
        return .init(keyword: "BZPOPMIN", arguments: args)
    }

    /// Removes the element from a sorted set with the highest score, blocking until an element is
    /// available.
    ///
    /// - Important:
    ///     This will block a connection from completing further commands until an element
    ///     is available to pop from the group of sets.
    ///
    ///     It is **highly** recommended to set a reasonable `timeout`
    ///     or to use the non-blocking `zpopmax` method where possible.
    ///
    /// See [https://redis.io/commands/bzpopmax](https://redis.io/commands/bzpopmax)
    /// - Parameters:
    ///     - keys: A list of sorted set keys in Redis.
    ///     - timeout: The max time to wait for a value to use. `0`seconds means to wait indefinitely.
    public static func bzpopmax(
        from keys: [RedisKey],
        timeout: TimeAmount = .seconds(0)
    ) -> NewRedisCommand<[RESPValue]?> {
        var args = keys.map(RESPValue.init)
        args.append(.init(bulk: timeout.seconds))
        return .init(keyword: "BZPOPMAX", arguments: args)
    }
}

// MARK: Increment

extension NewRedisCommand {
    /// Increments the score of the specified element in a sorted set.
    ///
    /// See [https://redis.io/commands/zincrby](https://redis.io/commands/zincrby)
    /// - Parameters:
    ///     - amount: The amount to increment this element's score by.
    ///     - element: The element to increment.
    ///     - key: The key of the sorted set.
    @inlinable
    public static func zincrby<Value: RESPValueConvertible>(
        _ amount: Double,
        element: Value,
        in key: RedisKey
    ) -> NewRedisCommand<Double> {
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: amount.description),
            element.convertedToRESPValue()
        ]
        return .init(keyword: "ZINCRBY", arguments: args)
    }
}

// MARK: Intersect and Union

extension NewRedisCommand {
    /// Calculates the union of two or more sorted sets and stores the result.
    /// - Note: This operation overwrites any value stored at the destination key.
    ///
    /// See [https://redis.io/commands/zunionstore](https://redis.io/commands/zunionstore)
    /// - Parameters:
    ///     - destination: The key of the new sorted set from the result.
    ///     - sources: The list of sorted set keys to treat as the source of the union.
    ///     - weights: The multiplying factor to apply to the corresponding `sources` key based on index of the two parameters.
    ///     - aggregateMethod: The method of aggregating the values of the union. If one isn't specified, Redis will default to `.sum`.
    public static func zunionstore(
        as destination: RedisKey,
        sources: [RedisKey],
        weights: [Int]? = nil,
        aggregateMethod aggregate: RedisSortedSetAggregateMethod? = nil
    ) -> NewRedisCommand<Int> {
        return ._zsetstore(command: "ZUNIONSTORE", sources, destination, weights, aggregate)
    }

    /// Calculates the intersection of two or more sorted sets and stores the result.
    /// - Note: This operation overwrites any value stored at the destination key.
    ///
    /// See [https://redis.io/commands/zinterstore](https://redis.io/commands/zinterstore)
    /// - Parameters:
    ///     - destination: The key of the new sorted set from the result.
    ///     - sources: The list of sorted set keys to treat as the source of the intersection.
    ///     - weights: The multiplying factor to apply to the corresponding `sources` key based on index of the two parameters.
    ///     - aggregateMethod: The method of aggregating the values of the intersection. If one isn't specified, Redis will default to `.sum`.
    public static func zinterstore(
        as destination: RedisKey,
        sources: [RedisKey],
        weights: [Int]? = nil,
        aggregateMethod aggregate: RedisSortedSetAggregateMethod? = nil
    ) -> NewRedisCommand<Int> {
        return ._zsetstore(command: "ZINTERSTORE", sources, destination, weights, aggregate)
    }
    
    private static func _zsetstore(
        command: String,
        _ sources: [RedisKey],
        _ destination: RedisKey,
        _ weights: [Int]?,
        _ aggregate: RedisSortedSetAggregateMethod?
    ) -> NewRedisCommand<Int> {
        assert(sources.count > 0, "At least 1 source key should be provided.")

        var args: [RESPValue] = [
            .init(bulk: destination),
            .init(bulk: sources.count)
        ]
        args.append(convertingContentsOf: sources)

        if let w = weights {
            assert(w.count > 0, "When passing a value for 'weights', at least 1 value should be provided.")
            assert(w.count <= sources.count, "Weights should be no larger than the amount of source keys.")

            args.append(.init(bulk: "WEIGHTS"))
            args.append(convertingContentsOf: w)
        }

        if let a = aggregate {
            args.append(.init(bulk: "AGGREGATE"))
            args.append(.init(bulk: a.rawValue))
        }
        
        return .init(keyword: command, arguments: args)
    }
}

// MARK: Range

extension NewRedisCommand {
    /// Gets all elements from a SortedSet within the specified inclusive bounds of 0-based indices.
    ///
    /// See [https://redis.io/commands/zrange](https://redis.io/commands/zrange)
    /// - Important: This treats the SortedSet as ordered from **low** to **high**.
    ///
    /// For the inverse, see `zrevrange(from:firstIndex:lastIndex:includeScoresInResponse:)`.
    /// - Parameters:
    ///     - key: The key of the SortedSet
    ///     - firstIndex: The index of the first element to include in the range of elements returned.
    ///     - lastIndex: The index of the last element to include in the range of elements returned.
    public static func zrange(
        from key: RedisKey,
        firstIndex: Int,
        lastIndex: Int,
        includeScoresInResponse includeScores: Bool = false
    ) -> NewRedisCommand<[RESPValue]> {
        return ._zrange(command: "ZRANGE", key, firstIndex, lastIndex, includeScores)
    }
    
    /// Gets all elements from a SortedSet within the specified inclusive bounds of 0-based indices.
    ///
    /// See [https://redis.io/commands/zrevrange](https://redis.io/commands/zrevrange)
    /// - Important: This treats the SortedSet as ordered from **high** to **low**.
    ///
    /// For the inverse, see `zrange(from:firstIndex:lastIndex:includeScoresInResponse:)`.
    /// - Parameters:
    ///     - key: The key of the SortedSet
    ///     - firstIndex: The index of the first element to include in the range of elements returned.
    ///     - lastIndex: The index of the last element to include in the range of elements returned.
    public static func zrevrange(
        from key: RedisKey,
        firstIndex: Int,
        lastIndex: Int,
        includeScoresInResponse includeScores: Bool = false
    ) -> NewRedisCommand<[RESPValue]> {
        return ._zrange(command: "ZREVRANGE", key, firstIndex, lastIndex, includeScores)
    }
    
    private static func _zrange(
        command: String,
        _ key: RedisKey,
        _ start: Int,
        _ stop: Int,
        _ withScores: Bool
    ) -> NewRedisCommand<[RESPValue]> {
        var args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: start),
            .init(bulk: stop)
        ]
        if withScores { args.append(.init(bulk: "WITHSCORES")) }
        return .init(keyword: command, arguments: args)
    }
}

// MARK: Range by Score

extension NewRedisCommand {
    /// Gets all elements from a SortedSet whose score is within the range specified.
    ///
    /// See `RedisZScoreBound` and [https://redis.io/commands/zrangebyscore](https://redis.io/commands/zrangebyscore)
    /// - Important: This treats the SortedSet as ordered from **low** to **high**.
    ///
    /// For the inverse, see `zrevrangebyscore(from:withScoresBetween:limitBy:includeScoresInResponse:)`.
    /// - Parameters:
    ///     - key: The key of the SortedSet.
    ///     - range: The min and max score bounds to filter elements by.
    ///     - limit: The optional offset and count of elements to query.
    ///     - includeScores: Should the response array contain the elements AND their scores? If `true`, the response array will follow the pattern [Item_1, Score_1, Item_2, ...]
    public static func zrangebyscore(
        from key: RedisKey,
        withScoresBetween range: (min: RedisZScoreBound, max: RedisZScoreBound),
        limitBy limit: (offset: Int, count: Int)? = nil,
        includeScoresInResponse includeScores: Bool = false
    ) -> NewRedisCommand<[RESPValue]> {
        return ._zrangebyscore(
            command: "ZRANGEBYSCORE",
            key,
            (range.min.description, range.max.description),
            includeScores, limit
        )
    }
    
    /// Gets all elements from a SortedSet whose score is within the range specified.
    ///
    /// See `RedisZScoreBound` and [https://redis.io/commands/zrangebyscore](https://redis.io/commands/zrangebyscore)
    /// - Important: This treats the SortedSet as ordered from **high** to **low**.
    ///
    /// For the inverse, see `zrangebyscore(from:withScoresBetween:limitBy:includeScoresInResponse:)`.
    /// - Parameters:
    ///     - key: The key of the SortedSet.
    ///     - range: The min and max score bounds to filter elements by.
    ///     - limit: The optional offset and count of elements to query.
    ///     - includeScores: Should the response array contain the elements AND their scores? If `true`, the response array will follow the pattern [Item_1, Score_1, Item_2, ...]
    public static func zrevrangebyscore(
        from key: RedisKey,
        withScoresBetween range: (min: RedisZScoreBound, max: RedisZScoreBound),
        limitBy limit: (offset: Int, count: Int)? = nil,
        includeScoresInResponse includeScores: Bool = false
    ) -> NewRedisCommand<[RESPValue]> {
        return ._zrangebyscore(
            command: "ZREVRANGEBYSCORE",
            key,
            (range.max.description, range.min.description),
            includeScores,
            limit
        )
    }

    private static func _zrangebyscore(
        command: String,
        _ key: RedisKey,
        _ range: (min: String, max: String),
        _ withScores: Bool,
        _ limit: (offset: Int, count: Int)?
    ) -> NewRedisCommand<[RESPValue]> {
        var args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: range.min),
            .init(bulk: range.max)
        ]
        if withScores { args.append(.init(bulk: "WITHSCORES")) }
        if let l = limit {
            args.append(.init(bulk: "LIMIT"))
            args.append(convertingContentsOf: [l.offset, l.count])
        }
        return .init(keyword: command, arguments: args)
    }
}

// MARK: Range by Lexiographical

extension NewRedisCommand {
    /// Gets all elements from a SortedSet whose lexiographical values are between the range specified.
    ///
    /// See `RedisZLexBound` and [https://redis.io/commands/zrangebylex](https://redis.io/commands/zrangebylex)
    /// - Warning: This assumes all elements in the SortedSet have the same score. If not, the returned elements are unspecified.
    /// - Important: This treats the SortedSet as ordered from **low** to **high**.
    ///
    /// For the inverse, see `zrevrangebylex(from:withValuesBetween:limitBy:)`.
    /// - Parameters:
    ///     - key: The key of the SortedSet that will be counted.
    ///     - range: The min and max value bounds for filtering elements by.
    ///     - limitBy: The optional offset and count of elements to query.
    @inlinable
    public static func zrangebylex<Value: CustomStringConvertible>(
        from key: RedisKey,
        withValuesBetween range: (min: RedisZLexBound<Value>, max: RedisZLexBound<Value>),
        limitBy limit: (offset: Int, count: Int)? = nil
    ) -> NewRedisCommand<[RESPValue]> {
        return ._zrangebylex(
            command: "ZRANGEBYLEX",
            key,
            (range.min.description, range.max.description),
            limit
        )
    }
    
    /// Gets all elements from a SortedSet whose lexiographical values are between the range specified.
    ///
    /// See `RedisZLexBound` and [https://redis.io/commands/zrevrangebylex](https://redis.io/commands/zrevrangebylex)
    /// - Warning: This assumes all elements in the SortedSet have the same score. If not, the returned elements are unspecified.
    /// - Important: This treats the SortedSet as ordered from **high** to **low**.
    ///
    /// For the inverse, see `zrangebylex(from:withValuesBetween:limitBy:)`.
    /// - Parameters:
    ///     - key: The key of the SortedSet that will be counted.
    ///     - range: The min and max value bounds for filtering elements by.
    ///     - limitBy: The optional offset and count of elements to query.
    @inlinable
    public static func zrevrangebylex<Value: CustomStringConvertible>(
        from key: RedisKey,
        withValuesBetween range: (min: RedisZLexBound<Value>, max: RedisZLexBound<Value>),
        limitBy limit: (offset: Int, count: Int)? = nil
    ) -> NewRedisCommand<[RESPValue]> {
        return ._zrangebylex(
            command: "ZREVRANGEBYLEX",
            key,
            (range.max.description, range.min.description),
            limit
        )
    }

    @usableFromInline
    internal static func _zrangebylex(
        command: String,
        _ key: RedisKey,
        _ range: (min: String, max: String),
        _ limit: (offset: Int, count: Int)?
    ) -> NewRedisCommand<[RESPValue]> {
        var args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: range.min),
            .init(bulk: range.max)
        ]
        if let l = limit {
            args.append(.init(bulk: "LIMIT"))
            args.append(convertingContentsOf: [l.offset, l.count])
        }
        return .init(keyword: command, arguments: args)
    }
}

// MARK: Remove

extension NewRedisCommand {
    /// Removes the specified elements from a sorted set.
    ///
    /// See [https://redis.io/commands/zrem](https://redis.io/commands/zrem)
    /// - Parameters:
    ///     - elements: The values to remove from the sorted set.
    ///     - key: The key of the sorted set.
    @inlinable
    public static func zrem<Value: RESPValueConvertible>(_ elements: [Value], from key: RedisKey) -> NewRedisCommand<Int> {
        var args: [RESPValue] = [.init(bulk: key)]
        args.append(convertingContentsOf: elements)
        return .init(keyword: "ZREM", arguments: args)
    }
}

// MARK: Remove by Lexiographical

extension NewRedisCommand {
    /// Removes elements from a SortedSet whose lexiographical values are between the range specified.
    ///
    /// See `RedisZLexBound` and [https://redis.io/commands/zremrangebylex](https://redis.io/commands/zremrangebylex)
    /// - Warning: This assumes all elements in the SortedSet have the same score. If not, the elements removed are unspecified.
    /// - Parameters:
    ///     - key: The key of the SortedSet to remove elements from.
    ///     - range: The min and max value bounds that an element should have to be removed.
    @inlinable
    public static func zremrangebylex<Value: CustomStringConvertible>(
        from key: RedisKey,
        withValuesBetween range: (min: RedisZLexBound<Value>, max: RedisZLexBound<Value>)
    ) -> NewRedisCommand<Int> {
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: range.min.description),
            .init(bulk: range.max.description)
        ]
        return .init(keyword: "ZREMRANGEBYLEX", arguments: args)
    }
}

// MARK: Remove by Rank

extension NewRedisCommand {
    /// Removes all elements from a SortedSet within the specified inclusive bounds of 0-based indices.
    ///
    /// See [https://redis.io/commands/zremrangebyrank](https://redis.io/commands/zremrangebyrank)
    /// - Parameters:
    ///     - key: The key of the SortedSet to remove elements from.
    ///     - firstIndex: The index of the first element to remove.
    ///     - lastIndex: The index of the last element to remove.
    public static func zremrangebyrank(from key: RedisKey, firstIndex: Int, lastIndex: Int) -> NewRedisCommand<Int> {
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: firstIndex),
            .init(bulk: lastIndex)
        ]
        return .init(keyword: "ZREMRANGEBYRANK", arguments: args)
    }
}

// MARK: Remove by Score

extension NewRedisCommand {
    /// Removes elements from a SortedSet whose score is within the range specified.
    ///
    /// See `RedisZScoreBound` and [https://redis.io/commands/zremrangebyscore](https://redis.io/commands/zremrangebyscore)
    /// - Parameters:
    ///     - key: The key of the SortedSet to remove elements from.
    ///     - range: The min and max score bounds to filter elements by.
    public static func zremrangebyscore(
        from key: RedisKey,
        withScoresBetween range: (min: RedisZScoreBound, max: RedisZScoreBound)
    ) -> NewRedisCommand<Int> {
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: range.min.description),
            .init(bulk: range.max.description)
        ]
        return .init(keyword: "ZREMRANGEBYSCORE", arguments: args)
    }
}

// MARK: Type-Safety Abstractions

/// The supported insert behavior for a `zadd` command with Redis SortedSet types.
///
/// `zadd` normally inserts all elements (`.allElements`) provided into the SortedSet, updating the score of any element that already exist in the set.
///
/// However, it supports two other insert behaviors:
/// * `.onlyNewElements` will not update the score of any element already in the SortedSet
/// * `.onlyExistingElements` will not insert any new element into the SortedSet
///
/// See [https://redis.io/commands/zadd#zadd-options-redis-302-or-greater](https://redis.io/commands/zadd#zadd-options-redis-302-or-greater)
public enum RedisZaddInsertBehavior: String {
    /// Insert new elements and update the score of existing elements.
    case allElements = ""
    /// Only insert new elements; do not update the score of existing elements.
    case onlyNewElements = "NX"
    /// Only update the score of existing elements; do not insert new elements.
    case onlyExistingElements = "XX"
}

/// The supported behavior for what a `zadd` command return value should represent.
///
/// `zadd` normally returns the number of new elements inserted into the set (`.insertedElementsCount`),
/// but also supports the option (`.changedElementsCount`) to return the number of elements changed as a result of the command.
///
/// "Changed" in this context refers to both new elements that were inserted and existing elements that had their score updated.
///
/// See [https://redis.io/commands/zadd](https://redis.io/commands/zadd)
public enum RedisZaddReturnBehavior: String {
    /// Count both new elements that were inserted into the SortedSet and existing elements that had their score updated.
    case changedElementsCount = "CH"
    /// Count only new elements that were inserted into the SortedSet.
    case insertedElementsCount = ""
}

/// Represents a range bound for use with the Redis SortedSet commands related to element scores.
///
/// This type conforms to `ExpressibleByFloatLiteral` and `ExpressibleByIntegerLiteral`, which will initialize to an `.inclusive` bound.
///
/// For example:
/// ```swift
/// let literalBound: RedisZScoreBound = 3 // .inclusive(3)
/// let otherLiteralBound: RedisZScoreBound = 3.0 // .inclusive(3)
/// let exclusiveBound = RedisZScoreBound.exclusive(4)
/// ```
public enum RedisZScoreBound: CustomStringConvertible, ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral {
    public typealias FloatLiteralType = Double
    public typealias IntegerLiteralType = Int64

    case inclusive(Double)
    case exclusive(Double)
    
    /// The underlying raw score value this bound represents.
    public var rawValue: Double {
        switch self {
        case let .inclusive(v), let .exclusive(v): return v
        }
    }
    public var description: String {
        switch self {
        case let .inclusive(value): return value.description
        case let .exclusive(value): return "(\(value.description)"
        }
    }
    
    public init(floatLiteral value: Double) {
        self = .inclusive(value)
    }
    public init(integerLiteral value: Int64) {
        self = .inclusive(Double(value))
    }
}

/// Represents a range bound for use with the Redis SortedSet lexiographical commands to compare values.
///
/// Cases must be explicitly declared, with wrapped values conforming to `CustomStringConvertible`.
///
/// The cases `.negativeInfinity` and `.positiveInfinity` represent the special characters in Redis of `-` and `+` respectively.
/// These are constants for absolute lower and upper value bounds that are always treated as _inclusive_.
///
/// See [https://redis.io/commands/zrangebylex#details-on-strings-comparison](https://redis.io/commands/zrangebylex#details-on-strings-comparison)
public enum RedisZLexBound<Value: CustomStringConvertible>: CustomStringConvertible {
    case inclusive(Value)
    case exclusive(Value)
    case positiveInfinity
    case negativeInfinity

    public var description: String {
        switch self {
        case let .inclusive(value): return "[\(value)"
        case let .exclusive(value): return "(\(value)"
        case .positiveInfinity: return "+"
        case .negativeInfinity: return "-"
        }
    }
}

extension RedisZLexBound where Value: BinaryFloatingPoint {
    public var description: String {
        switch self {
        case .inclusive(.infinity), .exclusive(.infinity), .positiveInfinity: return "+"
        case .inclusive(-.infinity), .exclusive(-.infinity), .negativeInfinity: return "-"
        case let .inclusive(value): return "[\(value)"
        case let .exclusive(value): return "(\(value)"
        }
    }
}

/// The supported methods for aggregating results from the `zunionstore` or `zinterstore` commands in Redis.
///
/// For more information on these values, see
/// [https://redis.io/commands/zunionstore](https://redis.io/commands/zunionstore)
/// [https://redis.io/commands/zinterstore](https://redis.io/commands/zinterstore)
public enum RedisSortedSetAggregateMethod: String {
    /// Add the score of all matching elements in the source SortedSets.
    case sum = "SUM"
    /// Use the minimum score of the matching elements in the source SortedSets.
    case min = "MIN"
    /// Use the maximum score of the matching elements in the source SortedSets.
    case max = "MAX"
}
