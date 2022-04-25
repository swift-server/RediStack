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

// MARK: Sorted Sets

extension RedisCommand {
    /// [BZPOPMIN](https://redis.io/commands/bzpopmin)
    /// - Warning:
    ///     This will block the connection from completing further commands until an element is available to pop from the group of sets.
    ///
    ///     It is **highly** recommended to set a reasonable `timeout` or to use the non-blocking `zpopmin` method where possible.
    /// - Parameters:
    ///     - key: The key identifying the sorted set in Redis.
    ///     - timeout: The max time to wait for a value to use. `0`seconds means to wait indefinitely.
    public static func bzpopmin(
        from key: RedisKey,
        timeout: TimeAmount = .seconds(0)
    ) -> RedisCommand<(Double, RESPValue)?> {
        return ._bzpop(keyword: "BZPOPMIN", [key], timeout, { result in
            result.map { ($0.1, $0.2) }
        })
    }

    /// [BZPOPMIN](https://redis.io/commands/bzpopmin)
    /// - Warning:
    ///     This will block the connection from completing further commands until an element is available to pop from the group of sets.
    ///
    ///     It is **highly** recommended to set a reasonable `timeout` or to use the non-blocking `zpopmin` method where possible.
    /// - Parameters:
    ///     - keys: A list of sorted set keys in Redis.
    ///     - timeout: The max time to wait for a value to use. `0`seconds means to wait indefinitely.
    public static func bzpopmin(
        from keys: [RedisKey],
        timeout: TimeAmount = .seconds(0)
    ) -> RedisCommand<(String, Double, RESPValue)?> { ._bzpop(keyword: "BZPOPMIN", keys, timeout, { $0 }) }

    /// [BZPOPMIN](https://redis.io/commands/bzpopmin)
    /// - Warning:
    ///     This will block the connection from completing further commands until an element is available to pop from the group of sets.
    ///
    ///     It is **highly** recommended to set a reasonable `timeout` or to use the non-blocking `zpopmin` method where possible.
    /// - Parameters:
    ///     - keys: A list of sorted set keys in Redis.
    ///     - timeout: The max time to wait for a value to use. `0`seconds means to wait indefinitely.
    public static func bzpopmin(
        from keys: RedisKey...,
        timeout: TimeAmount = .seconds(0)
    ) -> RedisCommand<(String, Double, RESPValue)?> { .bzpopmin(from: keys, timeout: timeout) }

    /// [BZPOPMAX](https://redis.io/commands/bzpopmax)
    /// - Warning:
    ///     This will block the connection from completing further commands until an element is available to pop from the set.
    ///
    ///     It is **highly** recommended to set a reasonable `timeout` or to use the non-blocking `zpopmax` method where possible.
    /// - Parameters:
    ///     - key: The key identifying the sorted set in Redis.
    ///     - timeout: The max time to wait for a value to use. `0`seconds means to wait indefinitely.
    public static func bzpopmax(
        from key: RedisKey,
        timeout: TimeAmount = .seconds(0)
    ) -> RedisCommand<(Double, RESPValue)?> {
        return ._bzpop(keyword: "BZPOPMAX", [key], timeout, { result in
            result.map { ($0.1, $0.2) }
        })
    }

    /// [BZPOPMAX](https://redis.io/commands/bzpopmax)
    /// - Warning:
    ///     This will block the connection from completing further commands until an element is available to pop from the set.
    ///
    ///     It is **highly** recommended to set a reasonable `timeout` or to use the non-blocking `zpopmax` method where possible.
    /// - Parameters:
    ///     - key: The key identifying the sorted set in Redis.
    ///     - timeout: The max time to wait for a value to use. `0`seconds means to wait indefinitely.
    public static func bzpopmax(
        from keys: [RedisKey],
        timeout: TimeAmount = .seconds(0)
    ) -> RedisCommand<(String, Double, RESPValue)?> { ._bzpop(keyword: "BZPOPMAX", keys, timeout, { $0 }) }

    /// [BZPOPMAX](https://redis.io/commands/bzpopmax)
    /// - Warning:
    ///     This will block the connection from completing further commands until an element is available to pop from the set.
    ///
    ///     It is **highly** recommended to set a reasonable `timeout` or to use the non-blocking `zpopmax` method where possible.
    /// - Parameters:
    ///     - key: The key identifying the sorted set in Redis.
    ///     - timeout: The max time to wait for a value to use. `0`seconds means to wait indefinitely.
    public static func bzpopmax(
        from keys: RedisKey...,
        timeout: TimeAmount = .seconds(0)
    ) -> RedisCommand<(String, Double, RESPValue)?> { .bzpopmax(from: keys, timeout: timeout) }

    /// [ZADD](https://redis.io/commands/zadd)
    /// - Parameters:
    ///     - element: The element and its score to add to the sorted set.
    ///     - key: The key of the sorted set.
    ///     - insertBehavior: The desired behavior of handling new and existing elements in the SortedSet.
    ///     - returnBehavior: The desired behavior of what the return value should represent.
    @inlinable
    public static func zadd<Value: RESPValueConvertible>(
        _ element: (value: Value, score: Double),
        to key: RedisKey,
        inserting insertBehavior: RedisZaddInsertBehavior = .allElements,
        returning returnBehavior: RedisZaddReturnBehavior = .insertedElementsCount
    ) -> RedisCommand<Bool> {
        var args = [RESPValue(from: key)]
        args.append(convertingContentsOf: [insertBehavior.string, returnBehavior.string].compactMap({ $0 }))
        args.append(contentsOf: [.init(bulk: element.score.description), element.value.convertedToRESPValue()])
        return .init(keyword: "ZADD", arguments: args)
    }

    /// [ZADD](https://redis.io/commands/zadd)
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
    ) -> RedisCommand<Int> {
        var args = [RESPValue(from: key)]

        args.append(convertingContentsOf: [insertBehavior.string, returnBehavior.string].compactMap({ $0 }))
        args.add(contentsOf: elements, overestimatedCountBeingAdded: elements.count * 2) { array, next in
            array.append(.init(bulk: next.score.description))
            array.append(next.element.convertedToRESPValue())
        }

        return .init(keyword: "ZADD", arguments: args)
    }

    /// [ZADD](https://redis.io/commands/zadd)
    /// - Parameters:
    ///     - elements: A list of elements and their score to add to the sorted set.
    ///     - key: The key of the sorted set.
    ///     - insertBehavior: The desired behavior of handling new and existing elements in the SortedSet.
    ///     - returnBehavior: The desired behavior of what the return value should represent.
    @inlinable
    public static func zadd<Value: RESPValueConvertible>(
        _ elements: (element: Value, score: Double)...,
        to key: RedisKey,
        inserting insertBehavior: RedisZaddInsertBehavior = .allElements,
        returning returnBehavior: RedisZaddReturnBehavior = .insertedElementsCount
    ) -> RedisCommand<Int> { .zadd(elements, to: key, inserting: insertBehavior, returning: returnBehavior) }

    /// [ZCARD](https://redis.io/commands/zcard)
    /// - Parameter key: The key of the sorted set.
    public static func zcard(of key: RedisKey) -> RedisCommand<Int> {
        let args = [RESPValue(from: key)]
        return .init(keyword: "ZCARD", arguments: args)
    }

    /// [ZCOUNT](https://redis.io/commands/zcount)
    ///
    /// Example usage:
    /// To get a count of elements that have at least the score of 3, but no greater than 10:
    /// ```swift
    /// // count elements with score of 3...10
    /// client.send(.zcount(of: "mySortedSet", withScoresBetween: (3, 10)))
    ///
    /// // count elements with score 3..<10
    /// client.send(.zcount(of: "mySortedSet", withScoresBetween: (3, .exclusive(10))))
    /// ```
    /// - Parameters:
    ///     - key: The key of the SortedSet that will be counted.
    ///     - range: The min and max score bounds that an element should have in order to be counted.
    public static func zcount(
        of key: RedisKey,
        withScoresBetween range: (min: RedisZScoreBound, max: RedisZScoreBound)
    ) -> RedisCommand<Int> {
        let args: [RESPValue] = [
            .init(from: key),
            .init(bulk: range.min.description),
            .init(bulk: range.max.description)
        ]
        return .init(keyword: "ZCOUNT", arguments: args)
    }

    /// [ZCOUNT](https://redis.io/commands/zcount)
    ///
    /// Example usage:
    /// ```swift
    /// // count of elements with at least score of 3, but no greater than 10
    /// client.send(.zcount(of: "mySortedSet", withScores: 3...10)
    /// ```
    /// - Parameters:
    ///     - key: The key of the SortedSet that will be counted.
    ///     - range: The inclusive range of scores to filter elements to count.
    public static func zcount(of key: RedisKey, withScores range: ClosedRange<Double>) -> RedisCommand<Int> {
        return .zcount(of: key, withScoresBetween: (.inclusive(range.lowerBound), .inclusive(range.upperBound)))
    }

    /// [ZCOUNT](https://redis.io/commands/zcount)
    ///
    /// Example usage:
    /// ```swift
    /// // count of elements with at least score of 3, but less than 10
    /// client.send(.zcount(of: "mySortedSet", withScores: 3..<10)
    /// ```
    /// - Parameters:
    ///     - key: The key of the SortedSet that will be counted.
    ///     - range: A range with an inclusive lower and exclusive upper bound of scores to filter elements to count.
    public static func zcount(of key: RedisKey, withScores range: Range<Double>) -> RedisCommand<Int> {
        return .zcount(of: key, withScoresBetween: (.inclusive(range.lowerBound), .exclusive(range.upperBound)))
    }

    /// [ZCOUNT](https://redis.io/commands/zcount)
    /// - Parameters:
    ///     - key: The key of the SortedSet that will be counted.
    ///     - minScore: The minimum score bound an element in the SortedSet should have in order to be counted.
    public static func zcount(of key: RedisKey, withMinimumScoreOf minScore: RedisZScoreBound) -> RedisCommand<Int> {
        return .zcount(of: key, withScoresBetween: (minScore, .inclusive(.infinity)))
    }

    /// [ZCOUNT](https://redis.io/commands/zcount)
    /// - Parameters:
    ///     - key: The key of the SortedSet that will be counted.
    ///     - maxScore: The maximum score bound an element in the SortedSet should have in order to be counted.
    public static func zcount(of key: RedisKey, withMaximumScoreOf maxScore: RedisZScoreBound) -> RedisCommand<Int> {
        return .zcount(of: key, withScoresBetween: (.inclusive(-.infinity), maxScore))
    }

    /// [ZINCRBY](https://redis.io/commands/zincrby)
    /// - Parameters:
    ///     - element: The element to increment.
    ///     - key: The key of the sorted set.
    ///     - amount: The amount to increment this element's score by.
    @inlinable
    public static func zincrby<Value: RESPValueConvertible>(
        _ element: Value,
        in key: RedisKey,
        by amount: Double
    ) -> RedisCommand<Double> {
        let args: [RESPValue] = [
            .init(from: key),
            .init(bulk: amount.description),
            element.convertedToRESPValue()
        ]
        return .init(keyword: "ZINCRBY", arguments: args)
    }

    /// [ZINTERSTORE](https://redis.io/commands/zinterstore)
    /// - Warning: This operation overwrites any value stored at the `destination` key.
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
    ) -> RedisCommand<Int> { ._zstore(keyword: "ZINTERSTORE", sources, destination, weights, aggregate) }

    /// [ZLEXCOUNT](https://redis.io/commands/zlexcount)
    ///
    /// Example usage:
    /// ```swift
    /// // "mySortedSet" contains the values [1, 2, 3, 10] each with a score of 1.
    ///
    /// client.send(.zlexcount(
    ///     of: "mySortedSet",
    ///     withValuesBetween: (.inclusive(1), .inclusive(3))
    /// ))
    /// // the response will resolve to 4, as both 10 and 1 have the value "1"
    /// ```
    /// - Warning: This assumes all elements in the SortedSet have the same score. If not, the returned elements are unspecified.
    /// - Parameters:
    ///     - key: The key of the SortedSet that will be counted.
    ///     - range: The min and max value bounds that an element should have in order to be counted.
    @inlinable
    public static func zlexcount<Value: CustomStringConvertible>(
        of key: RedisKey,
        withValuesBetween range: (min: RedisZLexBound<Value>, max: RedisZLexBound<Value>)
    ) -> RedisCommand<Int> {
        let args: [RESPValue] = [
            .init(from: key),
            .init(bulk: range.min.description),
            .init(bulk: range.max.description)
        ]
        return .init(keyword: "ZLEXCOUNT", arguments: args)
    }

    /// [ZLEXCOUNT](https://redis.io/commands/zlexcount)
    /// - Warning: This assumes all elements in the SortedSet have the same score. If not, the returned elements are unspecified.
    /// - Parameters:
    ///     - key: The key of the SortedSet that will be counted.
    ///     - minValue: The minimum lexiographical value an element in the SortedSet should have in order to be counted.
    @inlinable
    public static func zlexcount<Value: CustomStringConvertible>(
        of key: RedisKey,
        withMinimumValueOf minValue: RedisZLexBound<Value>
    ) -> RedisCommand<Int> { .zlexcount(of: key, withValuesBetween: (minValue, .positiveInfinity)) }

    /// [ZLEXCOUNT](https://redis.io/commands/zlexcount)
    /// - Warning: This assumes all elements in the SortedSet have the same score. If not, the returned elements are unspecified.
    /// - Parameters:
    ///     - key: The key of the SortedSet that will be counted.
    ///     - maxValue: The maximum lexiographical value an element in the SortedSet should have in order to be counted.
    @inlinable
    public static func zlexcount<Value: CustomStringConvertible>(
        of key: RedisKey,
        withMaximumValueOf maxValue: RedisZLexBound<Value>
    ) -> RedisCommand<Int> { .zlexcount(of: key, withValuesBetween: (.negativeInfinity, maxValue)) }

    /// [ZPOPMAX](https://redis.io/commands/zpopmax)
    /// - Parameter key: The key identifying the sorted set in Redis.
    public static func zpopmax(from key: RedisKey) -> RedisCommand<(RESPValue, Double)?> {
        return ._zpop(keyword: "ZPOPMAX", nil, key, { $0.isEmpty ? nil : $0[0] })
    }

    /// [ZPOPMAX](https://redis.io/commands/zpopmax)
    /// - Parameters:
    ///     - key: The key identifying the sorted set in Redis.
    ///     - count: The max number of elements to pop from the set.
    public static func zpopmax(from key: RedisKey, max count: Int) -> RedisCommand<[(RESPValue, Double)]> {
        return ._zpop(keyword: "ZPOPMAX", count, key, { $0 })
    }

    /// [ZPOPMIN](https://redis.io/commands/zpopmin)
    /// - Parameter key: The key identifying the sorted set in Redis.
    public static func zpopmin(from key: RedisKey) -> RedisCommand<(RESPValue, Double)?> {
        return ._zpop(keyword: "ZPOPMIN", nil, key, { $0.isEmpty ? nil : $0[0] })
    }

    /// [ZPOPMIN](https://redis.io/commands/zpopmin)
    /// - Parameters:
    ///     - key: The key identifying the sorted set in Redis.
    ///     - count: The max number of elements to pop from the set.
    public static func zpopmin(from key: RedisKey, max count: Int) -> RedisCommand<[(RESPValue, Double)]> {
        return ._zpop(keyword: "ZPOPMIN", count, key, { $0 })
    }

    /// [ZRANGE](https://redis.io/commands/zrange)
    /// - Parameters:
    ///     - key: The key of the SortedSet
    ///     - firstIndex: The index of the first element to include in the range of elements returned.
    ///     - lastIndex: The index of the last element to include in the range of elements returned.
    ///     - resultOption: What information should be returned in the result?
    @inlinable
    public static func zrange<T>(
        from key: RedisKey,
        firstIndex: Int,
        lastIndex: Int,
        returning resultOption: RedisZRangeResultOption<T>
    ) -> RedisCommand<T> { ._zrange(keyword: "ZRANGE", key, firstIndex, lastIndex, resultOption) }

    /// [ZRANGE](https://redis.io/commands/zrange)
    /// - Precondition: A `ClosedRange` cannot be created where `upperBound` is less than `lowerBound`; so while Redis may support `0...-1`,
    ///     `ClosedRange` will trigger a precondition failure.
    ///
    ///     If you need such a range, use ``zrange(from:firstIndex:lastIndex:resultOption:)`` instead.
    /// - Important: This treats the SortedSet as ordered from **low** to **high**.
    ///
    /// For the inverse, see `zrevrange(from:indices:returning:)`.
    /// - Parameters:
    ///     - key: The key of the SortedSet to return elements from.
    ///     - range: The range of inclusive indices of elements to get.
    ///     - resultOption: What information should be returned in the result?
    @inlinable
    public static func zrange<T>(
        from key: RedisKey,
        indices range: ClosedRange<Int>,
        returning resultOption: RedisZRangeResultOption<T>
    ) -> RedisCommand<T> {
        return .zrange(from: key, firstIndex: range.lowerBound, lastIndex: range.upperBound, returning: resultOption)
    }

    /// [ZRANGE](https://redis.io/commands/zrange)
    /// - Precondition: A `Range` cannot be created where `upperBound` is less than `lowerBound`; so while Redis may support `0..<(-1)`,
    ///     `Range` will trigger a precondition failure.
    ///
    ///     If you need such a range, use ``zrange(from:firstIndex:lastIndex:)`` instead.
    /// - Important: This treats the SortedSet as ordered from **low** to **high**.
    ///
    /// For the inverse, see `zrevrange(from:indices:returning:)`.
    /// - Parameters:
    ///     - key: The key of the SortedSet to return elements from.
    ///     - range: The range of indices (inclusive lower, exclusive upper) elements to get.
    ///     - resultOption: What information should be returned in the result?
    @inlinable
    public static func zrange<T>(
        from key: RedisKey,
        indices range: Range<Int>,
        returning resultOption: RedisZRangeResultOption<T>
    ) -> RedisCommand<T> {
        return .zrange(from: key, firstIndex: range.lowerBound, lastIndex: range.upperBound - 1, returning: resultOption)
    }

    /// [ZRANGE](https://redis.io/commands/zrange)
    /// - Important: This treats the SortedSet as ordered from **low** to **high**.
    ///
    /// For the inverse, see ``zrevrange(from:fromIndex:returning:)``.
    /// - Parameters:
    ///     - key: The key of the SortedSet to return elements from.
    ///     - index: The index of the first element that will be in the returned values.
    ///     - resultOption: What information should be returned in the result?
    @inlinable
    public static func zrange<T>(
        from key: RedisKey,
        fromIndex index: Int,
        returning resultOption: RedisZRangeResultOption<T>
    ) -> RedisCommand<T> {
        return .zrange(from: key, firstIndex: index, lastIndex: -1, returning: resultOption)
    }

    /// [ZRANGE](https://redis.io/commands/zrange)
    /// - Important: This treats the SortedSet as ordered from **low** to **high**.
    ///
    /// For the inverse, see ``zrevrange(from:throughIndex:returning:)`.
    /// - Parameters:
    ///     - key: The key of the SortedSet to return elements from.
    ///     - index: The index of the last element that will be in the returned values.
    ///     - resultOption: What information should be returned in the result?
    @inlinable
    public static func zrange<T>(
        from key: RedisKey,
        throughIndex index: Int,
        returning resultOption: RedisZRangeResultOption<T>
    ) -> RedisCommand<T> {
        return .zrange(from: key, firstIndex: 0, lastIndex: index, returning: resultOption)
    }

    /// [ZRANGE](https://redis.io/commands/zrange)
    /// - Important: This treats the SortedSet as ordered from **low** to **high**.
    ///
    /// For the inverse, see ``zrevrange(from:upToIndex:returning:)``.
    /// - Parameters:
    ///     - key: The key of the SortedSet to return elements from.
    ///     - index: The index of the last element to not include in the returned values.
    ///     - resultOption: What information should be returned in the result?
    @inlinable
    public static func zrange<T>(
        from key: RedisKey,
        upToIndex index: Int,
        returning resultOption: RedisZRangeResultOption<T>
    ) -> RedisCommand<T> {
        return .zrange(from: key, firstIndex: 0, lastIndex: index - 1, returning: resultOption)
    }

    /// [ZRANGEBYLEX](https://redis.io/commands/zrangebylex)
    /// - Warning: This assumes all elements in the SortedSet have the same score. If not, the returned elements are unspecified.
    /// - Important: This treats the SortedSet as ordered from **low** to **high**.
    ///
    /// For the inverse, see ``zrevrangebylex(from:withValuesBetween:limitBy:)``.
    /// - Parameters:
    ///     - key: The key of the SortedSet that will be counted.
    ///     - range: The min and max value bounds for filtering elements by.
    ///     - limitBy: The optional offset and count of elements to query.
    @inlinable
    public static func zrangebylex<Value: CustomStringConvertible>(
        from key: RedisKey,
        withValuesBetween range: (min: RedisZLexBound<Value>, max: RedisZLexBound<Value>),
        limitBy limit: (offset: Int, count: Int)? = nil
    ) -> RedisCommand<[RESPValue]> {
        return ._zrangebylex(keyword: "ZRANGEBYLEX", key, (range.min.description, range.max.description), limit)
    }

    /// [ZRANGEBYLEX](https://redis.io/commands/zrangebylex)
    /// - Warning: This assumes all elements in the SortedSet have the same score. If not, the returned elements are unspecified.
    /// - Important: This treats the SortedSet as ordered from **low** to **high**.
    ///
    /// For the inverse, see ``zrevrangebylex(from:withMinimumValueOf:limitBy:)``.
    /// - Parameters:
    ///     - key: The key of the SortedSet.
    ///     - minValue: The minimum lexiographical value an element in the SortedSet should have to be included in the result set.
    ///     - limit: The optional offset and count of elements to query
    @inlinable
    public static func zrangebylex<Value: CustomStringConvertible>(
        from key: RedisKey,
        withMinimumValueOf minValue: RedisZLexBound<Value>,
        limitBy limit: (offset: Int, count: Int)? = nil
    ) -> RedisCommand<[RESPValue]> {
        return .zrangebylex(from: key, withValuesBetween: (minValue, .positiveInfinity), limitBy: limit)
    }

    /// [ZRANGEBYLEX](https://redis.io/commands/zrangebylex)
    /// - Warning: This assumes all elements in the SortedSet have the same score. If not, the returned elements are unspecified.
    /// - Important: This treats the SortedSet as ordered from **low** to **high**.
    ///
    /// For the inverse, see ``zrevrangebylex(from:withMaximumValueOf:limitBy:)``.
    /// - Parameters:
    ///     - key: The key of the SortedSet.
    ///     - minValue: The maximum lexiographical value an element in the SortedSet should have to be included in the result set.
    ///     - limit: The optional offset and count of elements to query
    @inlinable
    public static func zrangebylex<Value: CustomStringConvertible>(
        from key: RedisKey,
        withMaximumValueOf maxValue: RedisZLexBound<Value>,
        limitBy limit: (offset: Int, count: Int)? = nil
    ) -> RedisCommand<[RESPValue]> {
        return .zrangebylex(from: key, withValuesBetween: (.negativeInfinity, maxValue), limitBy: limit)
    }

    /// [ZREVRANGEBYLEX](https://redis.io/commands/zrevrangebylex)
    /// - Warning: This assumes all elements in the SortedSet have the same score. If not, the returned elements are unspecified.
    /// - Important: This treats the SortedSet as ordered from **high** to **low**.
    ///
    /// For the inverse, see ``zrangebylex(from:withValuesBetween:limitBy:)`.
    /// - Parameters:
    ///     - key: The key of the SortedSet that will be counted.
    ///     - range: The min and max value bounds for filtering elements by.
    ///     - limitBy: The optional offset and count of elements to query.
    @inlinable
    public static func zrevrangebylex<Value: CustomStringConvertible>(
        from key: RedisKey,
        withValuesBetween range: (min: RedisZLexBound<Value>, max: RedisZLexBound<Value>),
        limitBy limit: (offset: Int, count: Int)? = nil
    ) -> RedisCommand<[RESPValue]> {
        return ._zrangebylex(keyword: "ZREVRANGEBYLEX", key, (range.max.description, range.min.description), limit)
    }

    /// [ZREVRANGEBYLEX](https://redis.io/commands/zrevrangebylex)
    /// - Warning: This assumes all elements in the SortedSet have the same score. If not, the returned elements are unspecified.
    /// - Important: This treats the SortedSet as ordered from **high** to **low**.
    ///
    /// For the inverse, see ``zrangebylex(from:withMinimumValueOf:limitBy:)``.
    /// - Parameters:
    ///     - key: The key of the SortedSet.
    ///     - minValue: The minimum lexiographical value an element in the SortedSet should have to be included in the result set.
    ///     - limit: The optional offset and count of elements to query
    @inlinable
    public static func zrevrangebylex<Value: CustomStringConvertible>(
        from key: RedisKey,
        withMinimumValueOf minValue: RedisZLexBound<Value>,
        limitBy limit: (offset: Int, count: Int)? = nil
    ) -> RedisCommand<[RESPValue]> {
        return .zrevrangebylex(from: key, withValuesBetween: (minValue, .positiveInfinity), limitBy: limit)
    }

    /// [ZREVRANGEBYLEX](https://redis.io/commands/zrevrangebylex)
    /// - Warning: This assumes all elements in the SortedSet have the same score. If not, the returned elements are unspecified.
    /// - Important: This treats the SortedSet as ordered from **high** to **low**.
    ///
    /// For the inverse, see ``zrangebylex(from:withMaximumValueOf:limitBy:)``.
    /// - Parameters:
    ///     - key: The key of the SortedSet.
    ///     - minValue: The maximum lexiographical value an element in the SortedSet should have to be included in the result set.
    ///     - limit: The optional offset and count of elements to query
    @inlinable
    public static func zrevrangebylex<Value: CustomStringConvertible>(
        from key: RedisKey,
        withMaximumValueOf maxValue: RedisZLexBound<Value>,
        limitBy limit: (offset: Int, count: Int)? = nil
    ) -> RedisCommand<[RESPValue]> {
        return .zrevrangebylex(from: key, withValuesBetween: (.negativeInfinity, maxValue), limitBy: limit)
    }

    /// [ZRANGEBYSCORE](https://redis.io/commands/zrangebyscore)
    /// - Important: This treats the SortedSet as ordered from **low** to **high**.
    ///
    /// For the inverse, see ``zrevrangebyscore(from:withScoresBetween:limitBy:returning:)``.
    /// - Parameters:
    ///     - key: The key of the SortedSet.
    ///     - range: The min and max score bounds to filter elements by.
    ///     - limit: The optional offset and count of elements to query.
    ///     - resultOption: What information should be returned in the result?
    @inlinable
    public static func zrangebyscore<T>(
        from key: RedisKey,
        withScoresBetween range: (min: RedisZScoreBound, max: RedisZScoreBound),
        limitBy limit: (offset: Int, count: Int)? = nil,
        returning resultOption: RedisZRangeResultOption<T>
    ) -> RedisCommand<T> {
        return ._zrangebyscore(keyword: "ZRANGEBYSCORE", key, (range.min.description, range.max.description), limit, resultOption)
    }

    /// [ZRANGEBYSCORE](https://redis.io/commands/zrangebyscore)
    /// - Important: This treats the SortedSet as ordered from **low** to **high**.
    ///
    /// For the inverse, see ``zrevrangebyscore(from:withScores:limitBy:returning:)-2vp67``.
    /// - Parameters:
    ///     - key: The key of the SortedSet.
    ///     - range: The inclusive range of scores to filter elements by.
    ///     - limit: The optional offset and count of elements to query.
    ///     - resultOption: What information should be returned in the result?
    @inlinable
    public static func zrangebyscore<T>(
        from key: RedisKey,
        withScores range: ClosedRange<Double>,
        limitBy limit: (offset: Int, count: Int)? = nil,
        returning resultOption: RedisZRangeResultOption<T>
    ) -> RedisCommand<T> {
        return .zrangebyscore(
            from: key,
            withScoresBetween: (.inclusive(range.lowerBound), .inclusive(range.upperBound)),
            limitBy: limit,
            returning: resultOption
        )
    }

    /// [ZRANGEBYSCORE](https://redis.io/commands/zrangebyscore)
    /// - Important: This treats the SortedSet as ordered from **low** to **high**.
    ///
    /// For the inverse, see ``zrevrangebyscore(from:withScores:limitBy:returning:)-3jdpl``.
    /// - Parameters:
    ///     - key: The key of the SortedSet.
    ///     - range: A range with an inclusive lower and exclusive upper bound of scores to filter elements by.
    ///     - limit: The optional offset and count of elements to query.
    ///     - resultOption: What information should be returned in the result?
    @inlinable
    public static func zrangebyscore<T>(
        from key: RedisKey,
        withScores range: Range<Double>,
        limitBy limit: (offset: Int, count: Int)? = nil,
        returning resultOption: RedisZRangeResultOption<T>
    ) -> RedisCommand<T> {
        return .zrangebyscore(
            from: key,
            withScoresBetween: (.inclusive(range.lowerBound), .exclusive(range.upperBound)),
            limitBy: limit,
            returning: resultOption
        )
    }

    /// [ZRANGEBYSCORE](https://redis.io/commands/zrangebyscore)
    /// - Important: This treats the SortedSet as ordered from **low** to **high**.
    ///
    /// For the inverse, see ``zrevrangebyscore(from:withMinimumScoreOf:limitBy:returning:)``.
    /// - Parameters:
    ///     - key: The key of the SortedSet.
    ///     - range: The minimum score bound an element in the SortedSet should have to be included in the response.
    ///     - limit: The optional offset and count of elements to query.
    ///     - resultOption: What information should be returned in the result?
    @inlinable
    public static func zrangebyscore<T>(
        from key: RedisKey,
        withMinimumScoreOf minScore: RedisZScoreBound,
        limitBy limit: (offset: Int, count: Int)? = nil,
        returning resultOption: RedisZRangeResultOption<T>
    ) -> RedisCommand<T> {
        return .zrangebyscore(
            from: key,
            withScoresBetween: (minScore, .inclusive(.infinity)),
            limitBy: limit,
            returning: resultOption
        )
    }

    /// [ZRANGEBYSCORE](https://redis.io/commands/zrangebyscore)
    /// - Important: This treats the SortedSet as ordered from **low** to **high**.
    ///
    /// For the inverse, see ``zrevrangebyscore(from:withMaximumScoreOf:limitBy:returning:)``.
    /// - Parameters:
    ///     - key: The key of the SortedSet.
    ///     - range: The maximum score bound an element in the SortedSet should have to be included in the response.
    ///     - limit: The optional offset and count of elements to query.
    ///     - resultOption: What information should be returned in the result?
    @inlinable
    public static func zrangebyscore<T>(
        from key: RedisKey,
        withMaximumScoreOf maxScore: RedisZScoreBound,
        limitBy limit: (offset: Int, count: Int)? = nil,
        returning resultOption: RedisZRangeResultOption<T>
    ) -> RedisCommand<T> {
        return .zrangebyscore(
            from: key,
            withScoresBetween: (.inclusive(-.infinity), maxScore),
            limitBy: limit,
            returning: resultOption
        )
    }

    /// [ZRANK](https://redis.io/commands/zrank)
    /// - Important: This treats the ordered set as ordered from low to high.
    ///
    /// For the inverse, see ``zrevrank(of:in:)``.
    /// - Parameters:
    ///     - element: The element in the sorted set to search for.
    ///     - key: The key of the sorted set to search.
    @inlinable
    public static func zrank<Value: RESPValueConvertible>(of element: Value, in key: RedisKey) -> RedisCommand<Int?> {
        let args: [RESPValue] = [
            .init(from: key),
            element.convertedToRESPValue()
        ]
        return .init(keyword: "ZRANK", arguments: args)
    }

    /// [ZREM](https://redis.io/commands/zrem)
    /// - Parameters:
    ///     - elements: The values to remove from the sorted set.
    ///     - key: The key of the sorted set.
    @inlinable
    public static func zrem<Value: RESPValueConvertible>(_ elements: [Value], from key: RedisKey) -> RedisCommand<Int> {
        var args = [RESPValue(from: key)]
        args.append(convertingContentsOf: elements)
        return .init(keyword: "ZREM", arguments: args)
    }

    /// [ZREM](https://redis.io/commands/zrem)
    /// - Parameters:
    ///     - elements: The values to remove from the sorted set.
    ///     - key: The key of the sorted set.
    @inlinable
    public static func zrem<Value: RESPValueConvertible>(_ elements: Value..., from key: RedisKey) -> RedisCommand<Int> {
        return .zrem(elements, from: key)
    }

    /// [ZREMRANGEBYLEX](https://redis.io/commands/zremrangebylex)
    /// - Warning: This assumes all elements in the SortedSet have the same score. If not, the elements removed are unspecified.
    /// - Parameters:
    ///     - key: The key of the SortedSet to remove elements from.
    ///     - range: The min and max value bounds that an element should have to be removed.
    @inlinable
    public static func zremrangebylex<Value: CustomStringConvertible>(
        from key: RedisKey,
        withValuesBetween range: (min: RedisZLexBound<Value>, max: RedisZLexBound<Value>)
    ) -> RedisCommand<Int> {
        let args: [RESPValue] = [
            .init(from: key),
            .init(bulk: range.min.description),
            .init(bulk: range.max.description)
        ]
        return .init(keyword: "ZREMRANGEBYLEX", arguments: args)
    }

    /// [ZREMRANGEBYLEX](https://redis.io/commands/zremrangebylex)
    /// - Warning: This assumes all elements in the SortedSet have the same score. If not, the elements removed are unspecified.
    /// - Parameters:
    ///     - key: The key of the SortedSet to remove elements from.
    ///     - minValue: The minimum lexiographical value an element in the SortedSet should have to be removed.
    @inlinable
    public static func zremrangebylex<Value: CustomStringConvertible>(
        from key: RedisKey,
        withMinimumValueOf minValue: RedisZLexBound<Value>
    ) -> RedisCommand<Int> { .zremrangebylex(from: key, withValuesBetween: (minValue, .positiveInfinity)) }

    /// [ZREMRANGEBYLEX](https://redis.io/commands/zremrangebylex)
    /// - Warning: This assumes all elements in the SortedSet have the same score. If not, the elements removed are unspecified.
    /// - Parameters:
    ///     - key: The key of the SortedSet to remove elements from.
    ///     - maxValue: The maximum lexiographical value and element in the SortedSet should have to be removed.
    @inlinable
    public static func zremrangebylex<Value: CustomStringConvertible>(
        from key: RedisKey,
        withMaximumValueOf maxValue: RedisZLexBound<Value>
    ) -> RedisCommand<Int> { .zremrangebylex(from: key, withValuesBetween: (.negativeInfinity, maxValue)) }

    /// [ZREMRANGEBYRANK](https://redis.io/commands/zremrangebyrank)
    /// - Parameters:
    ///     - key: The key of the SortedSet to remove elements from.
    ///     - firstIndex: The index of the first element to remove.
    ///     - lastIndex: The index of the last element to remove.
    public static func zremrangebyrank(from key: RedisKey, firstIndex: Int, lastIndex: Int) -> RedisCommand<Int> {
        let args: [RESPValue] = [
            .init(from: key),
            .init(bulk: firstIndex),
            .init(bulk: lastIndex)
        ]
        return .init(keyword: "ZREMRANGEBYRANK", arguments: args)
    }

    /// [ZREMRANGEBYRANK](https://redis.io/commands/zremrangebyrank)
    /// - Precondition: A `ClosedRange` cannot be created where `upperBound` is less than `lowerBound`; so while Redis may support `0...-1`,
    ///     `ClosedRange` will trigger a precondition failure.
    ///
    ///     If you need such a range, use ``zremrangebyrank(from:firstIndex:lastIndex:)`` instead.
    /// - Parameters:
    ///     - key: The key of the SortedSet to remove elements from.
    ///     - range: The range of inclusive indices of elements to remove.
    public static func zremrangebyrank(from key: RedisKey, indices range: ClosedRange<Int>) -> RedisCommand<Int> {
        return .zremrangebyrank(from: key, firstIndex: range.lowerBound, lastIndex: range.upperBound)
    }

    /// [ZREMRANGEBYRANK](https://redis.io/commands/zremrangebyrank)
    /// - Precondition: A `Range` cannot be created where `upperBound` is less than `lowerBound`; so while Redis may support `0...-1`,
    ///     `Range` will trigger a precondition failure.
    ///
    ///     If you need such a range, use ``zremrangebyrank(from:firstIndex:lastIndex:)`` instead.
    /// - Parameters:
    ///     - key: The key of the SortedSet to remove elements from.
    ///     - range: The range of indices (inclusive lower, exclusive upper) elements to remove.
    public static func zremrangebyrank(from key: RedisKey, indices range: Range<Int>) -> RedisCommand<Int> {
        return .zremrangebyrank(from: key, firstIndex: range.lowerBound, lastIndex: range.upperBound - 1)
    }

    /// [ZREMRANGEBYRANK](https://redis.io/commands/zremrangebyrank)
    /// - Parameters:
    ///     - key: The key of the SortedSet to remove elements from.
    ///     - index: The index of the first element that will be removed.
    public static func zremrangebyrank(from key: RedisKey, fromIndex index: Int) -> RedisCommand<Int> {
        return .zremrangebyrank(from: key, firstIndex: index, lastIndex: -1)
    }

    /// [ZREMRANGEBYRANK](https://redis.io/commands/zremrangebyrank)
    /// - Parameters:
    ///     - key: The key of the SortedSet to remove elements from.
    ///     - index: The index of the last element that will be removed.
    public static func zremrangebyrank(from key: RedisKey, throughIndex index: Int) -> RedisCommand<Int> {
        return .zremrangebyrank(from: key, firstIndex: 0, lastIndex: index)
    }

    /// [ZREMRANGEBYRANK](https://redis.io/commands/zremrangebyrank)
    /// - Warning: Providing an index of `0` will remove all elements from the SortedSet.
    /// - Parameters:
    ///     - key: The key of the SortedSet to remove elements from.
    ///     - index: The index of the last element to not remove.
    public static func zremrangebyrank(from key: RedisKey, upToIndex index: Int) -> RedisCommand<Int> {
        return .zremrangebyrank(from: key, firstIndex: 0, lastIndex: index - 1)
    }

    /// [ZREMRANGEBYSCORE](https://redis.io/commands/zremrangebyscore)
    /// - Parameters:
    ///     - key: The key of the SortedSet to remove elements from.
    ///     - range: The min and max score bounds to filter elements by.
    public static func zremrangebyscore(
        from key: RedisKey,
        withScoresBetween range: (min: RedisZScoreBound, max: RedisZScoreBound)
    ) -> RedisCommand<Int> {
        let args: [RESPValue] = [
            .init(from: key),
            .init(bulk: range.min.description),
            .init(bulk: range.max.description)
        ]
        return .init(keyword: "ZREMRANGEBYSCORE", arguments: args)
    }

    /// [ZREMRANGEBYSCORE](https://redis.io/commands/zremrangebyscore)
    /// - Parameters:
    ///     - key: The key of the SortedSet to remove elements from.
    ///     - range: The inclusive range of scores to filter elements by.
    public static func zremrangebyscore(from key: RedisKey, withScores range: ClosedRange<Double>) -> RedisCommand<Int> {
        return .zremrangebyscore(from: key, withScoresBetween: (.inclusive(range.lowerBound), .inclusive(range.upperBound)))
    }

    /// [ZREMRANGEBYSCORE](https://redis.io/commands/zremrangebyscore)
    /// - Parameters:
    ///     - key: The key of the SortedSet to remove elements from.
    ///     - range: A range with an inclusive lower and exclusive upper bound of scores to filter elements by.
    public static func zremrangebyscore(from key: RedisKey, withScores range: Range<Double>) -> RedisCommand<Int> {
        return .zremrangebyscore(from: key, withScoresBetween: (.inclusive(range.lowerBound), .exclusive(range.upperBound)))
    }

    /// [ZREMRANGEBYSCORE](https://redis.io/commands/zremrangebyscore)
    /// - Parameters:
    ///     - key: The key of the SortedSet to remove elements from.
    ///     - minScore: The minimum score bound an element in the SortedSet should have to be removed.
    public static func zremrangebyscore(from key: RedisKey, withMinimumScoreOf minScore: RedisZScoreBound) -> RedisCommand<Int> {
        return .zremrangebyscore(from: key, withScoresBetween: (minScore, .inclusive(.infinity)))
    }

    /// [ZREMRANGEBYSCORE](https://redis.io/commands/zremrangebyscore)
    /// - Parameters:
    ///     - key: The key of the SortedSet to remove elements from.
    ///     - minScore: The maximum score bound an element in the SortedSet should have to be removed.
    public static func zremrangebyscore(from key: RedisKey, withMaximumScoreOf maxScore: RedisZScoreBound) -> RedisCommand<Int> {
        return .zremrangebyscore(from: key, withScoresBetween: (.inclusive(-.infinity), maxScore))
    }

    /// [ZREVRANGE](https://redis.io/commands/zrevrange)
    /// - Important: This treats the SortedSet as ordered from **high** to **low**.
    ///
    /// For the inverse, see ``zrange(from:firstIndex:lastIndex:returning:)``.
    /// - Parameters:
    ///     - key: The key of the SortedSet
    ///     - firstIndex: The index of the first element to include in the range of elements returned.
    ///     - lastIndex: The index of the last element to include in the range of elements returned.
    ///     - resultOption: What information should be returned in the result?
    @inlinable
    public static func zrevrange<T>(
        from key: RedisKey,
        firstIndex: Int,
        lastIndex: Int,
        returning resultOption: RedisZRangeResultOption<T>
    ) -> RedisCommand<T> { ._zrange(keyword: "ZREVRANGE", key, firstIndex, lastIndex, resultOption) }

    /// [ZREVRANGE](https://redis.io/commands/zrevrange)
    /// - Precondition: A `ClosedRange` cannot be created where `upperBound` is less than `lowerBound`; so while Redis may support `0...-1`,
    ///     `ClosedRange` will trigger a precondition failure.
    ///
    ///     If you need such a range, use ``zrevrange(from:firstIndex:lastIndex:)`` instead.
    /// - Important: This treats the SortedSet as ordered from **high** to **low**.
    ///
    /// For the inverse, see ``zrange(from:indices:returning:)-95y9o``.
    /// - Parameters:
    ///     - key: The key of the SortedSet to return elements from.
    ///     - range: The range of inclusive indices of elements to get.
    ///     - resultOption: What information should be returned in the result?
    @inlinable
    public static func zrevrange<T>(
        from key: RedisKey,
        indices range: ClosedRange<Int>,
        returning resultOption: RedisZRangeResultOption<T>
    ) -> RedisCommand<T> { .zrevrange(from: key, firstIndex: range.lowerBound, lastIndex: range.upperBound, returning: resultOption) }

    /// [ZREVRANGE](https://redis.io/commands/zrevrange)
    /// - Precondition: A `Range` cannot be created where `upperBound` is less than `lowerBound`; so while Redis may support `0..<(-1)`,
    ///     `Range` will trigger a precondition failure.
    ///
    ///     If you need such a range, use ``zrevrange(from:firstIndex:lastIndex:)`` instead.
    /// - Important: This treats the SortedSet as ordered from **high** to **low**.
    ///
    /// For the inverse, see ``zrange(from:indices:returning:)-4pd8n``.
    /// - Parameters:
    ///     - key: The key of the SortedSet to return elements from.
    ///     - range: The range of indices (inclusive lower, exclusive upper) elements to get.
    ///     - resultOption: What information should be returned in the result?
    @inlinable
    public static func zrevrange<T>(
        from key: RedisKey,
        indices range: Range<Int>,
        returning resultOption: RedisZRangeResultOption<T>
    ) -> RedisCommand<T> { .zrevrange(from: key, firstIndex: range.lowerBound, lastIndex: range.upperBound - 1, returning: resultOption) }

    /// [ZREVRANGE](https://redis.io/commands/zrevrange)
    /// - Important: This treats the SortedSet as ordered from **high** to **low**.
    ///
    /// For the inverse, see ``zrange(from:fromIndex:returning:)``.
    /// - Parameters:
    ///     - key: The key of the SortedSet to return elements from.
    ///     - index: The index of the first element that will be in the returned values.
    ///     - resultOption: What information should be returned in the result?
    @inlinable
    public static func zrevrange<T>(
        from key: RedisKey,
        fromIndex index: Int,
        returning resultOption: RedisZRangeResultOption<T>
    ) -> RedisCommand<T> { .zrevrange(from: key, firstIndex: index, lastIndex: -1, returning: resultOption) }

    /// [ZREVRANGE](https://redis.io/commands/zrevrange)
    /// - Important: This treats the SortedSet as ordered from **high** to **low**.
    ///
    /// For the inverse, see ``zrange(from:throughIndex:returning:)``.
    /// - Parameters:
    ///     - key: The key of the SortedSet to return elements from.
    ///     - index: The index of the last element that will be in the returned values.
    ///     - resultOption: What information should be returned in the result?
    @inlinable
    public static func zrevrange<T>(
        from key: RedisKey,
        throughIndex index: Int,
        returning resultOption: RedisZRangeResultOption<T>
    ) -> RedisCommand<T> { .zrevrange(from: key, firstIndex: 0, lastIndex: index, returning: resultOption) }

    /// [ZREVRANGE](https://redis.io/commands/zrevrange)
    /// - Important: This treats the SortedSet as ordered from **high** to **low**.
    ///
    /// For the inverse, see ``zrange(from:upToIndex:returning:)``.
    /// - Parameters:
    ///     - key: The key of the SortedSet to return elements from.
    ///     - index: The index of the last element to not include in the returned values.
    ///     - resultOption: What information should be returned in the result?
    @inlinable
    public static func zrevrange<T>(
        from key: RedisKey,
        upToIndex index: Int,
        returning resultOption: RedisZRangeResultOption<T>
    ) -> RedisCommand<T> { .zrevrange(from: key, firstIndex: 0, lastIndex: index - 1, returning: resultOption) }

    /// [ZREVRANGEBYSCORE](https://redis.io/commands/zrevrangebyscore)
    /// - Important: This treats the SortedSet as ordered from **high** to **low**.
    ///
    /// For the inverse, see ``zrangebyscore(from:withScoresBetween:limitBy:returning:)``.
    /// - Parameters:
    ///     - key: The key of the SortedSet.
    ///     - range: The min and max score bounds to filter elements by.
    ///     - limit: The optional offset and count of elements to query.
    ///     - resultOption: What information should be returned in the result?
    @inlinable
    public static func zrevrangebyscore<T>(
        from key: RedisKey,
        withScoresBetween range: (min: RedisZScoreBound, max: RedisZScoreBound),
        limitBy limit: (offset: Int, count: Int)? = nil,
        returning resultOption: RedisZRangeResultOption<T>
    ) -> RedisCommand<T> {
        return ._zrangebyscore(keyword: "ZREVRANGEBYSCORE", key, (range.max.description, range.min.description), limit, resultOption)
    }

    /// [ZREVRANGEBYSCORE](https://redis.io/commands/zrevrangebyscore)
    /// - Important: This treats the SortedSet as ordered from **high** to **low**.
    ///
    /// For the inverse, see ``zrangebyscore(from:withScores:limitBy:returning:)-phw``.
    /// - Parameters:
    ///     - key: The key of the SortedSet.
    ///     - range: The inclusive range of scores to filter elements by.
    ///     - limit: The optional offset and count of elements to query.
    ///     - resultOption: What information should be returned in the result?
    @inlinable
    public static func zrevrangebyscore<T>(
        from key: RedisKey,
        withScores range: ClosedRange<Double>,
        limitBy limit: (offset: Int, count: Int)? = nil,
        returning resultOption: RedisZRangeResultOption<T>
    ) -> RedisCommand<T> {
        return .zrevrangebyscore(
            from: key,
            withScoresBetween: (.inclusive(range.lowerBound), .inclusive(range.upperBound)),
            limitBy: limit,
            returning: resultOption
        )
    }

    /// [ZREVRANGEBYSCORE](https://redis.io/commands/zrevrangebyscore)
    /// - Important: This treats the SortedSet as ordered from **high** to **low**.
    ///
    /// For the inverse, see ``zrangebyscore(from:withScores:limitBy:returning:)-4ukbv``.
    /// - Parameters:
    ///     - key: The key of the SortedSet.
    ///     - range: A range with an inclusive lower and exclusive upper bound of scores to filter elements by.
    ///     - limit: The optional offset and count of elements to query.
    ///     - resultOption: What information should be returned in the result?
    @inlinable
    public static func zrevrangebyscore<T>(
        from key: RedisKey,
        withScores range: Range<Double>,
        limitBy limit: (offset: Int, count: Int)? = nil,
        returning resultOption: RedisZRangeResultOption<T>
    ) -> RedisCommand<T> {
        return .zrevrangebyscore(
            from: key,
            withScoresBetween: (.inclusive(range.lowerBound), .exclusive(range.upperBound)),
            limitBy: limit,
            returning: resultOption
        )
    }

    /// [ZREVRANGEBYSCORE](https://redis.io/commands/zrevrangebyscore)
    /// - Important: This treats the SortedSet as ordered from **high** to **low**.
    ///
    /// For the inverse, see ``zrangebyscore(from:withMinimumScoreOf:limitBy:returning:)``.
    /// - Parameters:
    ///     - key: The key of the SortedSet.
    ///     - range: The minimum score bound an element in the SortedSet should have to be included in the response.
    ///     - limit: The optional offset and count of elements to query.
    ///     - resultOption: What information should be returned in the result?
    @inlinable
    public static func zrevrangebyscore<T>(
        from key: RedisKey,
        withMinimumScoreOf minScore: RedisZScoreBound,
        limitBy limit: (offset: Int, count: Int)? = nil,
        returning resultOption: RedisZRangeResultOption<T>
    ) -> RedisCommand<T> {
        return .zrevrangebyscore(
            from: key,
            withScoresBetween: (minScore, .inclusive(.infinity)),
            limitBy: limit,
            returning: resultOption
        )
    }

    /// [ZREVRANGEBYSCORE](https://redis.io/commands/zrevrangebyscore)
    /// - Important: This treats the SortedSet as ordered from **high** to **low**.
    ///
    /// For the inverse, see ``zrangebyscore(from:withMaximumScoreOf:limitBy:returning:)``.
    /// - Parameters:
    ///     - key: The key of the SortedSet.
    ///     - range: The maximum score bound an element in the SortedSet should have to be included in the response.
    ///     - limit: The optional offset and count of elements to query.
    ///     - resultOption: What information should be returned in the result?
    @inlinable
    public static func zrevrangebyscore<T>(
        from key: RedisKey,
        withMaximumScoreOf maxScore: RedisZScoreBound,
        limitBy limit: (offset: Int, count: Int)? = nil,
        returning resultOption: RedisZRangeResultOption<T>
    ) -> RedisCommand<T> {
        return .zrevrangebyscore(
            from: key,
            withScoresBetween: (.inclusive(-.infinity), maxScore),
            limitBy: limit,
            returning: resultOption
        )
    }

    /// [ZREVRANK](https://redis.io/commands/zrevrank)
    /// - Important: This treats the ordered set as ordered from high to low.
    ///
    /// For the inverse, see ``zrank(of:in:)``.
    /// - Parameters:
    ///     - element: The element in the sorted set to search for.
    ///     - key: The key of the sorted set to search.
    @inlinable
    public static func zrevrank<Value: RESPValueConvertible>(of element: Value, in key: RedisKey) -> RedisCommand<Int?> {
        let args: [RESPValue] = [
            .init(from: key),
            element.convertedToRESPValue()
        ]
        return .init(keyword: "ZREVRANK", arguments: args)
    }

    /// [ZSCORE](https://redis.io/commands/zscore)
    /// - Parameters:
    ///     - element: The element in the sorted set to get the score for.
    ///     - key: The key of the sorted set.
    @inlinable
    public static func zscore<Value: RESPValueConvertible>(of element: Value, in key: RedisKey) -> RedisCommand<Double?> {
        let args: [RESPValue] = [
            .init(from: key),
            element.convertedToRESPValue()
        ]
        return .init(keyword: "ZSCORE", arguments: args) { try? $0.map() }
    }

    /// [ZUNIONSTORE](https://redis.io/commands/zunionstore)
    /// - Warning: This operation overwrites any value stored at the destination key.
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
    ) -> RedisCommand<Int> { ._zstore(keyword: "ZUNIONSTORE", sources, destination, weights, aggregate) }

    /// [ZSCAN](https://redis.io/commands/zscan)
    /// - Parameters:
    ///     - key: The key identifying the sorted set.
    ///     - position: The position to start the scan from.
    ///     - match: A glob-style pattern to filter values to be selected from the result set.
    ///     - count: The number of elements to advance by. Redis default is 10.
    public static func zscan(
        _ key: RedisKey,
        startingFrom position: Int = 0,
        matching match: String? = nil,
        count: Int? = nil
    ) -> RedisCommand<(Int, [(RESPValue, Double)])> {
        return ._scan(keyword: "ZSCAN", key, position, match, count, {
            let response = try $0.map(to: [RESPValue].self)
            return try Self._mapSortedSetResponse(response, scoreIsFirst: false)
        })
    }
}

// MARK: -

extension RedisClient {
    /// Incrementally iterates over all elements in a sorted set.
    ///
    /// See ``RedisCommand/zscan(_:startingFrom:matching:count:)``
    /// - Parameters:
    ///     - key: The key identifying the sorted set.
    ///     - position: The position to start the scan from.
    ///     - match: A glob-style pattern to filter values to be selected from the result set.
    ///     - count: The number of elements to advance by. Redis default is 10.
    ///     - eventLoop: An optional event loop to hop to for any further chaining on the returned event loop future.
    ///     - logger: An optional logger instance to use for logs generated from this command.
    /// - Returns: A `NIO.EventLoopFuture` that resolves a cursor position for additional scans,
    ///     with a limited collection of elements with their scores found in the Sorted Set.
    public func scanSortedSetValues(
        in key: RedisKey,
        startingFrom position: Int = 0,
        matching match: String? = nil,
        count: Int? = nil,
        eventLoop: EventLoop? = nil,
        logger: Logger? = nil
    ) -> EventLoopFuture<(Int, [(RESPValue, Double)])> {
        return self.send(.zscan(key, startingFrom: position, matching: match, count: count), eventLoop: eventLoop, logger: logger)
    }
}

// MARK: -

/// The supported insert behavior for a `zadd` command with Redis SortedSet types.
///
/// `zadd` normally inserts all given elements into the SortedSet, updating the score of any element that already exist in the set.
///
/// See [ZADD Options](https://redis.io/commands/zadd#zadd-options).
public struct RedisZaddInsertBehavior {
    /// Insert new elements and update the score of existing elements.
    public static let allElements = RedisZaddInsertBehavior(nil)
    /// Only insert new elements; do not update the score of existing elements.
    public static let onlyNewElements = RedisZaddInsertBehavior(.nx)
    /// Only update the score of existing elements; do not insert new elements.
    public static let onlyExistingElements = RedisZaddInsertBehavior(.xx)

    @usableFromInline
    internal var string: String? { self.option?.rawValue }

    /// Redis representation of this option.
    private enum Option: String {
        case nx = "NX"
        case xx = "XX"
    }

    private let option: Option?
    private init(_ option: Option?) { self.option = option }
}

/// The supported behavior for what a `zadd` command return value should represent.
///
/// `zadd` normally returns the number of new elements inserted into the set,
/// but also supports the option to return the number of elements changed as a result of the command.
///
/// "Changed" in this context refers to both new elements that were inserted and existing elements that had their score updated.
///
/// See [ZADD Options](https://redis.io/commands/zadd#zadd-options)
public struct RedisZaddReturnBehavior {
    /// Count both new elements that were inserted into the SortedSet and existing elements that had their score updated.
    public static let changedElementsCount = RedisZaddReturnBehavior(.ch)
    /// Count only new elements that were inserted into the SortedSet.
    public static let insertedElementsCount = RedisZaddReturnBehavior(nil)

    @usableFromInline
    internal var string: String? { self.option?.rawValue }

    /// Redis representation of this option.
    private enum Option: String {
        case ch = "CH"
    }

    private let option: Option?
    private init(_ option: Option?) { self.option = option }
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
public enum RedisZScoreBound:
    CustomStringConvertible,
    ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral
{
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
    
    public init(floatLiteral value: Double) { self = .inclusive(value) }
    public init(integerLiteral value: Int64) { self = .inclusive(Double(value)) }
}

/// The supported methods for aggregating results from various Sorted Set algorithm commands in Redis.
///
/// See the documentation for each individual command that uses this object for more details.
public struct RedisSortedSetAggregateMethod {
    /// Add the score of all matching elements in the source SortedSets.
    public static let sum = RedisSortedSetAggregateMethod(.sum)
    /// Use the minimum score of the matching elements in the source SortedSets.
    public static let min = RedisSortedSetAggregateMethod(.min)
    /// Use the maximum score of the matching elements in the source SortedSets.
    public static let max = RedisSortedSetAggregateMethod(.max)

    internal var string: String { self.option.rawValue }

    /// Redis representation of this option.
    private enum Option: String {
        case sum = "SUM"
        case min = "MIN"
        case max = "MAX"
    }

    private let option: Option
    private init(_ option: Option) { self.option = option }
}

/// Represents a range bound for use with the Redis SortedSet lexiographical commands to compare values.
///
/// Cases must be explicitly declared, with wrapped values conforming to `CustomStringConvertible`.
///
/// The cases `.negativeInfinity` and `.positiveInfinity` represent the special characters in Redis of `-` and `+` respectively.
/// These are constants for absolute lower and upper value bounds that are always treated as _inclusive_.
///
/// See [Redis' string comparison documentation](https://redis.io/commands/zrangebylex#details-on-strings-comparison).
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

/// A representation of the range of options for the results that can be returned from Sorted Set range operations.
///
/// This correlates to the `WITHSCORES` option in Redis terminology.
public struct RedisZRangeResultOption<ResultType> {
    /// Returns the scores in addition to the values of elements in a Sorted Set.
    public static var valuesAndScores: RedisZRangeResultOption<[(RESPValue, Double)]> {
        return .init(true) {
            return try RedisCommand<Void>._mapSortedSetResponse($0, scoreIsFirst: false)
        }
    }
    /// Returns only the values of elements in a Sorted Set.
    public static var valuesOnly: RedisZRangeResultOption<[RESPValue]> {
        return .init(false, { $0 })
    }
    
    fileprivate let includeScores: Bool
    fileprivate let transform: ([RESPValue]) throws -> ResultType
    private init(_ includeScores: Bool, _ transform: @escaping ([RESPValue]) throws -> ResultType) {
        self.includeScores = includeScores
        self.transform = transform
    }
}

// MARK: - Shared implementations
extension RedisCommand {
    fileprivate static func _bzpop<ResultType>(
        keyword: String,
        _ keys: [RedisKey],
        _ timeout: TimeAmount,
        _ transform: @escaping ((String, Double, RESPValue)?) throws -> ResultType?
    ) -> RedisCommand<ResultType?> {
        var args = keys.map(RESPValue.init(from:))
        args.append(.init(bulk: timeout.seconds))
        return .init(keyword: keyword, arguments: args) {
            guard !$0.isNull else { return nil }

            let response = try $0.map(to: [RESPValue].self)
            assert(response.count == 3, "unexpected response size returned")
            guard
                let key = response[0].string,
                let score = Double(fromRESP: response[1])
            else {
                throw RedisClientError.assertionFailure(message: "unexpected structure in response: \(response)")
            }

            return try transform((key, score, response[2]))
        }
    }

    fileprivate static func _zstore(
        keyword: String,
        _ sources: [RedisKey],
        _ destination: RedisKey,
        _ weights: [Int]?,
        _ aggregate: RedisSortedSetAggregateMethod?
    ) -> RedisCommand<Int> {
        assert(sources.count > 0, "at least 1 source key should be provided")

        var args: [RESPValue] = [
            .init(from: destination),
            .init(bulk: sources.count)
        ]
        args.append(convertingContentsOf: sources)

        if let w = weights {
            assert(w.count > 0, "when passing a value for 'weights', at least 1 value should be provided")
            assert(w.count <= sources.count, "weights should be no larger than the amount of source keys")

            args.append(.init(bulk: "WEIGHTS"))
            args.append(convertingContentsOf: w)
        }
        if let a = aggregate {
            args.append(.init(bulk: "AGGREGATE"))
            args.append(.init(bulk: a.string))
        }

        return .init(keyword: keyword, arguments: args)
    }

    fileprivate static func _zpop<ResultType>(
        keyword: String,
        _ count: Int?,
        _ key: RedisKey,
        _ transform: @escaping ([(RESPValue, Double)]) -> ResultType
    ) -> RedisCommand<ResultType> {
        var args = [RESPValue(from: key)]

        if let c = count { args.append(.init(bulk: c)) }

        return .init(keyword: keyword, arguments: args) {
            let response = try $0.map(to: [RESPValue].self)
            let result = try Self._mapSortedSetResponse(response, scoreIsFirst: true)
            return transform(result)
        }
    }

    @usableFromInline
    internal static func _zrange<T>(
        keyword: String,
        _ key: RedisKey,
        _ start: Int,
        _ stop: Int,
        _ resultOption: RedisZRangeResultOption<T>
    ) -> RedisCommand<T> {
        var args: [RESPValue] = [
            .init(from: key),
            .init(bulk: start),
            .init(bulk: stop)
        ]
        if resultOption.includeScores { args.append(.init(bulk: "WITHSCORES")) }
        return .init(keyword: keyword, arguments: args) {
            let response = try $0.map(to: [RESPValue].self)
            return try resultOption.transform(response)
        }
    }

    @usableFromInline
    internal static func _zrangebylex(
        keyword: String,
        _ key: RedisKey,
        _ range: (min: String, max: String),
        _ limit: (offset: Int, count: Int)?
    ) -> RedisCommand<[RESPValue]> {
        var args: [RESPValue] = [
            .init(from: key),
            .init(bulk: range.min),
            .init(bulk: range.max)
        ]
        if let l = limit {
            args.append(.init(bulk: "LIMIT"))
            args.append(.init(bulk: l.offset))
            args.append(.init(bulk: l.count))
        }
        return .init(keyword: keyword, arguments: args)
    }

    @usableFromInline
    internal static func _zrangebyscore<T>(
        keyword: String,
        _ key: RedisKey,
        _ range: (min: String, max: String),
        _ limit: (offset: Int, count: Int)?,
        _ resultOption: RedisZRangeResultOption<T>
    ) -> RedisCommand<T> {
        var args: [RESPValue] = [
            .init(from: key),
            .init(bulk: range.min),
            .init(bulk: range.max)
        ]
        if resultOption.includeScores { args.append(.init(bulk: "WITHSCORES")) }
        if let l = limit {
            args.append(.init(bulk: "LIMIT"))
            args.append(.init(bulk: l.offset))
            args.append(.init(bulk: l.count))
        }
        return .init(keyword: keyword, arguments: args) {
            let response = try $0.map(to: [RESPValue].self)
            return try resultOption.transform(response)
        }
    }

    fileprivate static func _mapSortedSetResponse(_ response: [RESPValue], scoreIsFirst: Bool) throws -> [(RESPValue, Double)] {
        let responseCount = response.count
        guard responseCount > 0 else { return [] }

        var result: [(RESPValue, Double)] = []
        result.reserveCapacity(responseCount / 2) // every other RESPValue is the count
        
        var index = 0
        repeat {
            let scoreItem = response[scoreIsFirst ? index : index + 1]

            guard let score = Double(fromRESP: scoreItem) else {
                throw RedisClientError.assertionFailure(message: "unexpected response: '\(scoreItem)'")
            }

            let elementIndex = scoreIsFirst ? index + 1 : index
            result.append((response[elementIndex], score))

            index += 2
        } while (index < responseCount)

        return result
    }
}
