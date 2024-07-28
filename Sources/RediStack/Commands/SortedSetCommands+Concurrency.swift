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

import NIOCore

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension RedisClient {
    /// Adds elements to a sorted set, assigning their score to the values provided.
    ///
    /// See [https://redis.io/commands/zadd](https://redis.io/commands/zadd)
    /// - Parameters:
    ///     - elements: A list of elements and their score to add to the sorted set.
    ///     - key: The key of the sorted set.
    ///     - insertBehavior: The desired behavior of handling new and existing elements in the SortedSet.
    ///     - returnBehavior: The desired behavior of what the return value should represent.
    /// - Returns: If `returning` is `.changedElementsCount`, the number of elements inserted and that had their score updated. Otherwise, just the number of new elements inserted.
    @inlinable
    public func zadd<Value: RESPValueConvertible>(
        _ elements: [(element: Value, score: Double)],
        to key: RedisKey,
        inserting insertBehavior: RedisZaddInsertBehavior = .allElements,
        returning returnBehavior: RedisZaddReturnBehavior = .insertedElementsCount
    ) async throws -> Int {
    }

    /// Adds elements to a sorted set, assigning their score to the values provided.
    ///
    /// See [https://redis.io/commands/zadd](https://redis.io/commands/zadd)
    /// - Parameters:
    ///     - elements: A list of elements and their score to add to the sorted set.
    ///     - key: The key of the sorted set.
    ///     - insertBehavior: The desired behavior of handling new and existing elements in the SortedSet.
    ///     - returnBehavior: The desired behavior of what the return value should represent.
    /// - Returns: If `returning` is `.changedElementsCount`, the number of elements inserted and that had their score updated. Otherwise, just the number of new elements inserted.
    @inlinable
    public func zadd<Value: RESPValueConvertible>(
        _ elements: (element: Value, score: Double)...,
        to key: RedisKey,
        inserting insertBehavior: RedisZaddInsertBehavior = .allElements,
        returning returnBehavior: RedisZaddReturnBehavior = .insertedElementsCount
    ) async throws -> Int {
    }

    /// Adds an element to a sorted set, assigning their score to the value provided.
    ///
    /// See [https://redis.io/commands/zadd](https://redis.io/commands/zadd)
    /// - Parameters:
    ///     - element: The element and its score to add to the sorted set.
    ///     - key: The key of the sorted set.
    ///     - insertBehavior: The desired behavior of handling new and existing elements in the SortedSet.
    ///     - returnBehavior: The desired behavior of what the return value should represent.
    /// - Returns: If `returning` is `.changedElementsCount`, the number of elements inserted and that had their score updated. Otherwise, just the number of new elements inserted.
    @inlinable
    public func zadd<Value: RESPValueConvertible>(
        _ element: (element: Value, score: Double),
        to key: RedisKey,
        inserting insertBehavior: RedisZaddInsertBehavior = .allElements,
        returning returnBehavior: RedisZaddReturnBehavior = .insertedElementsCount
    ) async throws -> Bool {
    }
}

// MARK: General

extension RedisClient {
    /// Gets the number of elements in a sorted set.
    ///
    /// See [https://redis.io/commands/zcard](https://redis.io/commands/zcard)
    /// - Parameter key: The key of the sorted set.
    /// - Returns: The number of elements in the sorted set.
    public func zcard(of key: RedisKey) async throws -> Int {
    }

    /// Gets the score of the specified element in a stored set.
    ///
    /// See [https://redis.io/commands/zscore](https://redis.io/commands/zscore)
    /// - Parameters:
    ///     - element: The element in the sorted set to get the score for.
    ///     - key: The key of the sorted set.
    /// - Returns: The score of the element provided, or `nil` if the element is not found in the set or the set does not exist.
    @inlinable
    public func zscore<Value: RESPValueConvertible>(of element: Value, in key: RedisKey) async throws -> Double? {
    }

    /// Incrementally iterates over all elements in a sorted set.
    ///
    /// See [https://redis.io/commands/zscan](https://redis.io/commands/zscan)
    /// - Parameters:
    ///     - key: The key identifying the sorted set.
    ///     - position: The position to start the scan from.
    ///     - match: A glob-style pattern to filter values to be selected from the result set.
    ///     - count: The number of elements to advance by. Redis default is 10.
    /// - Returns: A cursor position for additional invocations with a limited collection of elements found in the sorted set with their scores.
    public func zscan(
        _ key: RedisKey,
        startingFrom position: Int = 0,
        matching match: String? = nil,
        count: Int? = nil
    ) async throws -> (Int, [(RESPValue, Double)]) {
    }

    /// Incrementally iterates over all elements in a sorted set.
    ///
    /// See [https://redis.io/commands/zscan](https://redis.io/commands/zscan)
    /// - Parameters:
    ///     - key: The key identifying the sorted set.
    ///     - position: The position to start the scan from.
    ///     - match: A glob-style pattern to filter values to be selected from the result set.
    ///     - count: The number of elements to advance by. Redis default is 10.
    ///     - valueType: The type to convert the values to.
    /// - Returns: A cursor position for additional invocations with a limited collection of elements found in the sorted set with their scores.
    ///     Any element that fails the `RESPValue` conversion will be `nil`.
    @inlinable
    public func zscan<Value: RESPValueConvertible>(
        _ key: RedisKey,
        startingFrom position: Int = 0,
        matching match: String? = nil,
        count: Int? = nil,
        valueType: Value.Type
    ) async throws -> (Int, [(Value, Double)?]) {
    }
}

// MARK: Rank

extension RedisClient {
    /// Returns the rank (index) of the specified element in a sorted set.
    /// - Note: This treats the ordered set as ordered from low to high.
    /// For the inverse, see `zrevrank(of:in:)`.
    ///
    /// See [https://redis.io/commands/zrank](https://redis.io/commands/zrank)
    /// - Parameters:
    ///     - element: The element in the sorted set to search for.
    ///     - key: The key of the sorted set to search.
    /// - Returns: The index of the element, or `nil` if the key was not found.
    @inlinable
    public func zrank<Value: RESPValueConvertible>(of element: Value, in key: RedisKey) async throws -> Int? {
    }

    /// Returns the rank (index) of the specified element in a sorted set.
    /// - Note: This treats the ordered set as ordered from high to low.
    /// For the inverse, see `zrank(of:in:)`.
    ///
    /// See [https://redis.io/commands/zrevrank](https://redis.io/commands/zrevrank)
    /// - Parameters:
    ///     - element: The element in the sorted set to search for.
    ///     - key: The key of the sorted set to search.
    /// - Returns: The index of the element, or `nil` if the key was not found.
    @inlinable
    public func zrevrank<Value: RESPValueConvertible>(of element: Value, in key: RedisKey) async throws -> Int? {
    }
}

// MARK: Count

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension RedisClient {
    /// Returns the count of elements in a SortedSet with a score within the range specified (inclusive by default).
    ///
    /// To get a count of elements that have at least the score of 3, but no greater than 10:
    /// ```swift
    /// client.zcount(of: "mySortedSet", withScoresBetween: (3, 10))
    /// ```
    ///
    /// To get a count of elements that have at least the score of 3, but less than 10:
    /// ```swift
    /// client.zcount(of: "mySortedSet", withScoresBetween: (3, .exclusive(10)))
    /// ```
    ///
    /// See `RedisZScoreBound` and [https://redis.io/commands/zcount](https://redis.io/commands/zcount)
    /// - Parameters:
    ///     - key: The key of the SortedSet that will be counted.
    ///     - range: The min and max score bounds that an element should have in order to be counted.
    /// - Returns: The count of elements in the SortedSet with a score matching the range specified.
    public func zcount(
        of key: RedisKey,
        withScoresBetween range: (min: RedisZScoreBound, max: RedisZScoreBound)
    ) async throws -> Int {
    }

    /// Returns the count of elements in a SortedSet with a score within the inclusive range specified.
    ///
    /// To get a count of elements that have at least the score of 3, but no greater than 10:
    /// ```swift
    /// client.zcount(of: "mySortedSet", withScores: 3...10)
    /// ```
    ///
    /// See [https://redis.io/commands/zcount](https://redis.io/commands/zcount)
    /// - Parameters:
    ///     - key: The key of the SortedSet that will be counted.
    ///     - range: The inclusive range of scores to filter elements to count.
    /// - Returns: The count of elements in the SortedSet with a score within the range specified.
    public func zcount(of key: RedisKey, withScores range: ClosedRange<Double>) async throws -> Int {
    }

    /// Returns the count of elements in a SortedSet with a minimum score up to, but not including, a max score.
    ///
    /// To get a count of elements that have at least the score of 3, but less than 10:
    /// ```swift
    /// client.zcount(of: "mySortedSet", withScores: 3..<10)
    /// ```
    ///
    /// See [https://redis.io/commands/zcount](https://redis.io/commands/zcount)
    /// - Parameters:
    ///     - key: The key of the SortedSet that will be counted.
    ///     - range: A range with an inclusive lower and exclusive upper bound of scores to filter elements to count.
    /// - Returns: The count of elements in the SortedSet with a score within the range specified.
    public func zcount(of key: RedisKey, withScores range: Range<Double>) async throws -> Int {
    }

    /// Returns the count of elements in a SortedSet whose score is greater than a minimum score value.
    ///
    /// By default, the value provided will be treated as _inclusive_, meaning any element that has a score matching the value **will** be counted.
    ///
    /// See `RedisZScoreBound` and [https://redis.io/commands/zcount](https://redis.io/commands/zcount)
    /// - Parameters:
    ///     - key: The key of the SortedSet that will be counted.
    ///     - minScore: The minimum score bound an element in the SortedSet should have in order to be counted.
    /// - Returns: The count of elements in the SortedSet above the `minScore` threshold.
    public func zcount(of key: RedisKey, withMinimumScoreOf minScore: RedisZScoreBound) async throws -> Int {
    }

    /// Returns the count of elements in a SortedSet whose score is less than a maximum score value.
    ///
    /// By default, the value provided will be treated as _inclusive_, meaning any element that has a score matching the value **will** be counted.
    ///
    /// See `RedisZScoreBound` and [https://redis.io/commands/zcount](https://redis.io/commands/zcount)
    /// - Parameters:
    ///     - key: The key of the SortedSet that will be counted.
    ///     - maxScore: The maximum score bound an element in the SortedSet should have in order to be counted.
    ///     - exclusive: Should the `maxScore` provided be exclusive? If `true`, scores matching the `maxScore` will **not** be counted.
    /// - Returns: The count of elements in the SortedSet below the `maxScore` threshold.
    public func zcount(of key: RedisKey, withMaximumScoreOf maxScore: RedisZScoreBound) async throws -> Int {
    }
}

// MARK: Lexiographical Count

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension RedisClient {
    /// Returns the count of elements in a SortedSet whose lexiographical values are between the range specified.
    ///
    /// For example:
    /// ```swift
    /// // "mySortedSet" contains the values [1, 2, 3, 10] each with a score of 1.
    /// client.zlexcount(of: "mySortedSet", withValuesBetween: (.inclusive(1), .inclusive(3)))
    /// // the response will resolve to 4, as both 10 and 1 have the value "1"
    /// ```
    ///
    /// See `RedisZLexBound` and [https://redis.io/commands/zlexcount](https://redis.io/commands/zlexcount)
    /// - Warning: This assumes all elements in the SortedSet have the same score. If not, the returned elements are unspecified.
    /// - Parameters:
    ///     - key: The key of the SortedSet that will be counted.
    ///     - range: The min and max value bounds that an element should have in order to be counted.
    /// - Returns: The count of elements in the SortedSet with values matching the range specified.
    @inlinable
    public func zlexcount<Value: CustomStringConvertible>(
        of key: RedisKey,
        withValuesBetween range: (min: RedisZLexBound<Value>, max: RedisZLexBound<Value>)
    ) async throws -> Int {
    }

    /// Returns the count of elements in a SortedSet whose lexiographical value is greater than a minimum value.
    ///
    /// For example with a SortedSet that contains the values [1, 2, 3, 10] and each a score of 1:
    /// ```swift
    /// client.zlexcount(of: "mySortedSet", withMinimumValueOf: .inclusive(2))
    /// // the response will resolve to 2, as "10" lexiographically comes before element "2"
    ///
    /// client.zlexcount(of: "mySortedSet", withMinimumValueOf: .inclusive(10))
    /// // the response will resolve to 3, as the set is ordered as ["1", "10", "2", "3"]
    /// ```
    ///
    /// See `RedisZLexBound` and [https://redis.io/commands/zlexcount](https://redis.io/commands/zlexcount)
    /// - Warning: This assumes all elements in the SortedSet have the same score. If not, the returned elements are unspecified.
    /// - Parameters:
    ///     - key: The key of the SortedSet that will be counted.
    ///     - minValue: The minimum lexiographical value an element in the SortedSet should have in order to be counted.
    /// - Returns: The count of elements in the SortedSet above the `minValue` threshold.
    @inlinable
    public func zlexcount<Value: CustomStringConvertible>(
        of key: RedisKey,
        withMinimumValueOf minValue: RedisZLexBound<Value>
    ) async throws -> Int {
    }

    /// Returns the count of elements in a SortedSet whose lexiographical value is less than a maximum value.
    ///
    /// For example with a SortedSet that contains the values [1, 2, 3, 10] and each a score of 1:
    /// ```swift
    /// client.zlexcount(of: "mySortedSet", withMaximumValueOf: .exclusive(10))
    /// // the response will resolve to 1, as "1" and "10" are sorted into the first 2 elements
    ///
    /// client.zlexcount(of: "mySortedSet", withMaximumValueOf: .inclusive(3))
    /// // the response will resolve to 4, as the set is ordered as ["1", "10", "2", "3"]
    /// ```
    ///
    /// See `RedisZLexBound` and [https://redis.io/commands/zlexcount](https://redis.io/commands/zlexcount)
    /// - Warning: This assumes all elements in the SortedSet have the same score. If not, the returned elements are unspecified.
    /// - Parameters:
    ///     - key: The key of the SortedSet that will be counted.
    ///     - maxValue: The maximum lexiographical value an element in the SortedSet should have in order to be counted.
    /// - Returns: The count of elements in the SortedSet below the `maxValue` threshold.
    @inlinable
    public func zlexcount<Value: CustomStringConvertible>(
        of key: RedisKey,
        withMaximumValueOf maxValue: RedisZLexBound<Value>
    ) async throws -> Int {
    }
}

// MARK: Pop

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension RedisClient {
    /// Removes elements from a sorted set with the lowest scores.
    ///
    /// See [https://redis.io/commands/zpopmin](https://redis.io/commands/zpopmin)
    /// - Parameters:
    ///     - key: The key identifying the sorted set in Redis.
    ///     - count: The max number of elements to pop from the set.
    /// - Returns: A list of elements popped from the sorted set with their associated score.
    public func zpopmin(from key: RedisKey, max count: Int) async throws -> [(RESPValue, Double)] {
    }

    /// Removes the element from a sorted set with the lowest score.
    ///
    /// See [https://redis.io/commands/zpopmin](https://redis.io/commands/zpopmin)
    /// - Parameter key: The key identifying the sorted set in Redis.
    /// - Returns: The element and its associated score that was popped from the sorted set, or `nil` if set was empty.
    public func zpopmin(from key: RedisKey) async throws -> (RESPValue, Double)? {
    }

    /// Removes elements from a sorted set with the highest scores.
    ///
    /// See [https://redis.io/commands/zpopmax](https://redis.io/commands/zpopmax)
    /// - Parameters:
    ///     - key: The key identifying the sorted set in Redis.
    ///     - count: The max number of elements to pop from the set.
    /// - Returns: A list of elements popped from the sorted set with their associated score.
    public func zpopmax(from key: RedisKey, max count: Int) async throws -> [(RESPValue, Double)] {
    }

    /// Removes the element from a sorted set with the highest score.
    ///
    /// See [https://redis.io/commands/zpopmax](https://redis.io/commands/zpopmax)
    /// - Parameter key: The key identifying the sorted set in Redis.
    /// - Returns: The element and its associated score that was popped from the sorted set, or `nil` if set was empty.
    public func zpopmax(from key: RedisKey) async throws -> (RESPValue, Double)? {
    }
}

// MARK: Blocking Pop

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension RedisClient {
    /// Removes the element from a sorted set with the lowest score, blocking until an element is
    /// available.
    ///
    /// - Important:
    ///     This will block the connection from completing further commands until an element
    ///     is available to pop from the set.
    ///
    ///     It is **highly** recommended to set a reasonable `timeout`
    ///     or to use the non-blocking `zpopmin` method where possible.
    ///
    /// See [https://redis.io/commands/bzpopmin](https://redis.io/commands/bzpopmin)
    /// - Parameters:
    ///     - key: The key identifying the sorted set in Redis.
    ///     - timeout: The max time to wait for a value to use. `0`seconds means to wait indefinitely.
    /// - Returns:
    ///     The element and its associated score that was popped from the sorted set,
    ///     or `nil` if the timeout was reached.
    public func bzpopmin(
        from key: RedisKey,
        timeout: TimeAmount = .seconds(0)
    ) async throws -> (Double, RESPValue)? {
    }

    /// Removes the element from a sorted set with the lowest score, blocking until an element is
    /// available.
    ///
    /// - Important:
    ///     This will block the connection from completing further commands until an element
    ///     is available to pop from the group of sets.
    ///
    ///     It is **highly** recommended to set a reasonable `timeout`
    ///     or to use the non-blocking `zpopmin` method where possible.
    ///
    /// See [https://redis.io/commands/bzpopmin](https://redis.io/commands/bzpopmin)
    /// - Parameters:
    ///     - keys: A list of sorted set keys in Redis.
    ///     - timeout: The max time to wait for a value to use. `0`seconds means to wait indefinitely.
    /// - Returns:
    ///     If timeout was reached, `nil`.
    ///
    ///     Otherwise, the key of the sorted set the element was removed from, the element itself,
    ///     and its associated score is returned.
    public func bzpopmin(
        from keys: [RedisKey],
        timeout: TimeAmount = .seconds(0)
    ) async throws -> (String, Double, RESPValue)? {
    }

    /// Removes the element from a sorted set with the highest score, blocking until an element is
    /// available.
    ///
    /// - Important:
    ///     This will block the connection from completing further commands until an element
    ///     is available to pop from the set.
    ///
    ///     It is **highly** recommended to set a reasonable `timeout`
    ///     or to use the non-blocking `zpopmax` method where possible.
    ///
    /// See [https://redis.io/commands/bzpopmax](https://redis.io/commands/bzpopmax)
    /// - Parameters:
    ///     - key: The key identifying the sorted set in Redis.
    ///     - timeout: The max time to wait for a value to use. `0`seconds means to wait indefinitely.
    /// - Returns:
    ///     The element and its associated score that was popped from the sorted set,
    ///     or `nil` if the timeout was reached.
    public func bzpopmax(
        from key: RedisKey,
        timeout: TimeAmount = .seconds(0)
    ) async throws -> (Double, RESPValue)? {
    }

    /// Removes the element from a sorted set with the highest score, blocking until an element is
    /// available.
    ///
    /// - Important:
    ///     This will block the connection from completing further commands until an element
    ///     is available to pop from the group of sets.
    ///
    ///     It is **highly** recommended to set a reasonable `timeout`
    ///     or to use the non-blocking `zpopmax` method where possible.
    ///
    /// See [https://redis.io/commands/bzpopmax](https://redis.io/commands/bzpopmax)
    /// - Parameters:
    ///     - keys: A list of sorted set keys in Redis.
    ///     - timeout: The max time to wait for a value to use. `0`seconds means to wait indefinitely.
    /// - Returns:
    ///     If timeout was reached, `nil`.
    ///
    ///     Otherwise, the key of the sorted set the element was removed from, the element itself,
    ///     and its associated score is returned.
    public func bzpopmax(
        from keys: [RedisKey],
        timeout: TimeAmount = .seconds(0)
    ) async throws -> (String, Double, RESPValue)? {
    }
}

// MARK: Increment

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension RedisClient {
    /// Increments the score of the specified element in a sorted set.
    ///
    /// See [https://redis.io/commands/zincrby](https://redis.io/commands/zincrby)
    /// - Parameters:
    ///     - amount: The amount to increment this element's score by.
    ///     - element: The element to increment.
    ///     - key: The key of the sorted set.
    /// - Returns: The new score of the element.
    @inlinable
    public func zincrby<Value: RESPValueConvertible>(
        _ amount: Double,
        element: Value,
        in key: RedisKey
    ) async throws -> Double {
    }
}

// MARK: Intersect and Union

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension RedisClient {
    /// Calculates the union of two or more sorted sets and stores the result.
    /// - Note: This operation overwrites any value stored at the destination key.
    ///
    /// See [https://redis.io/commands/zunionstore](https://redis.io/commands/zunionstore)
    /// - Parameters:
    ///     - destination: The key of the new sorted set from the result.
    ///     - sources: The list of sorted set keys to treat as the source of the union.
    ///     - weights: The multiplying factor to apply to the corresponding `sources` key based on index of the two parameters.
    ///     - aggregateMethod: The method of aggregating the values of the union. If one isn't specified, Redis will default to `.sum`.
    /// - Returns: The number of elements in the new sorted set.
    public func zunionstore(
        as destination: RedisKey,
        sources: [RedisKey],
        weights: [Int]? = nil,
        aggregateMethod aggregate: RedisSortedSetAggregateMethod? = nil
    ) async throws -> Int {
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
    /// - Returns: The number of elements in the new sorted set.
    public func zinterstore(
        as destination: RedisKey,
        sources: [RedisKey],
        weights: [Int]? = nil,
        aggregateMethod aggregate: RedisSortedSetAggregateMethod? = nil
    ) async throws -> Int {
    }
}

// MARK: Range

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension RedisClient {
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
    /// - Returns: An array of elements found within the range specified.
    public func zrange(
        from key: RedisKey,
        firstIndex: Int,
        lastIndex: Int,
        includeScoresInResponse includeScores: Bool = false
    ) async throws -> [RESPValue] {
    }

    /// Gets all elements from a SortedSet within the specified inclusive bounds of 0-based indices.
    ///
    /// To get the elements at index 4 through 7:
    /// ```swift
    /// client.zrange(from: "mySortedSet", indices: 4...7)
    /// ```
    ///
    /// To get the last 4 elements:
    /// ```swift
    /// client.zrange(from: "mySortedSet", indices: (-4)...(-1))
    /// ```
    ///
    /// To get the first and last 4 elements:
    /// ```swift
    /// client.zrange(from: "mySortedSet", indices: (-4)...3)
    /// ```
    ///
    /// To get the first element, and the last 4:
    /// ```swift
    /// client.zrange(from: "mySortedSet", indices: (-4)...0))
    /// ```
    ///
    /// See [https://redis.io/commands/zrange](https://redis.io/commands/zrange)
    /// - Warning: A `ClosedRange` cannot be created where `upperBound` is less than `lowerBound`; so while Redis may support `0...-1`,
    ///     `ClosedRange` will trigger a precondition failure.
    ///
    ///     If you need such a range, use `zrange(from:firstIndex:lastIndex:)` instead.
    /// - Important: This treats the SortedSet as ordered from **low** to **high**.
    ///
    /// For the inverse, see `zrevrange(from:indices:includeScoresInResponse:)`.
    /// - Parameters:
    ///     - key: The key of the SortedSet to return elements from.
    ///     - range: The range of inclusive indices of elements to get.
    /// - Returns: An array of elements found within the range specified.
    public func zrange(
        from key: RedisKey,
        indices range: ClosedRange<Int>,
        includeScoresInResponse includeScores: Bool = false
    ) async throws -> [RESPValue] {
    }

    /// Gets all the elements from a SortedSet starting with the first index bound up to, but not including, the element at the last index bound.
    ///
    /// To get the elements at index 4 through 7:
    /// ```swift
    /// client.zrange(from: "mySortedSet", indices: 4..<8)
    /// ```
    ///
    /// To get the last 4 elements:
    /// ```swift
    /// client.zrange(from: "mySortedSet", indices: (-4)..<0)
    /// ```
    ///
    /// To get the first and last 4 elements:
    /// ```swift
    /// client.zrange(from: "mySortedSet", indices: (-4)..<4)
    /// ```
    ///
    /// To get the first element, and the last 4:
    /// ```swift
    /// client.zrange(from: "mySortedSet", indices: (-4)..<1)
    /// ```
    ///
    /// See [https://redis.io/commands/zrange](https://redis.io/commands/zrange)
    /// - Warning: A `Range` cannot be created where `upperBound` is less than `lowerBound`; so while Redis may support `0..<(-1)`,
    ///     `Range` will trigger a precondition failure.
    ///
    ///     If you need such a range, use `zrange(from:firstIndex:lastIndex:)` instead.
    /// - Important: This treats the SortedSet as ordered from **low** to **high**.
    ///
    /// For the inverse, see `zrevrange(from:indices:includeScoresInResponse:)`.
    /// - Parameters:
    ///     - key: The key of the SortedSet to return elements from.
    ///     - range: The range of indices (inclusive lower, exclusive upper) elements to get.
    /// - Returns: An array of elements found within the range specified.
    public func zrange(
        from key: RedisKey,
        indices range: Range<Int>,
        includeScoresInResponse includeScores: Bool = false
    ) async throws -> [RESPValue] {
    }

    /// Gets all elements from the index specified to the end of a SortedSet.
    ///
    /// To get all except the first 2 elements of a SortedSet:
    /// ```swift
    /// client.zrange(from: "mySortedSet", fromIndex: 2)
    /// ```
    ///
    /// To get the last 4 elements of a SortedSet:
    /// ```swift
    /// client.zrange(from: "mySortedSet", fromIndex: -4)
    /// ```
    ///
    /// See `zrange(from:indices:)`, `zrange(from:firstIndex:lastIndex:)`, and [https://redis.io/commands/zrange](https://redis.io/commands/zrange)
    /// - Important: This treats the SortedSet as ordered from **low** to **high**.
    ///
    /// For the inverse, see `zrevrange(from:fromIndex:includeScoresInResponse:)`.
    /// - Parameters:
    ///     - key: The key of the SortedSet to return elements from.
    ///     - index: The index of the first element that will be in the returned values.
    /// - Returns: An array of elements from the SortedSet between the index and the end.
    public func zrange(
        from key: RedisKey,
        fromIndex index: Int,
        includeScoresInResponse includeScores: Bool = false
    ) async throws -> [RESPValue] {
    }

    /// Gets all elements from the start of a SortedSet up to, and including, the element at the index specified.
    ///
    /// To get the first 3 elements of a SortedSet:
    /// ```swift
    /// client.zrange(from: "mySortedSet", throughIndex: 2)
    /// ```
    ///
    /// To get all except the last 3 elements of a SortedSet:
    /// ```swift
    /// client.zrange(from: "mySortedSet", throughIndex: -4)
    /// ```
    ///
    /// See `zrange(from:indices:)`, `zrange(from:firstIndex:lastIndex:)`, and [https://redis.io/commands/zrange](https://redis.io/commands/zrange)
    /// - Important: This treats the SortedSet as ordered from **low** to **high**.
    ///
    /// For the inverse, see `zrevrange(from:throughIndex:includeScoresInResponse:)`.
    /// - Parameters:
    ///     - key: The key of the SortedSet to return elements from.
    ///     - index: The index of the last element that will be in the returned values.
    /// - Returns: An array of elements from the start of a SortedSet to the index.
    public func zrange(
        from key: RedisKey,
        throughIndex index: Int,
        includeScoresInResponse includeScores: Bool = false
    ) async throws -> [RESPValue] {
    }

    /// Gets all elements from the start of a SortedSet up to, but not including, the element at the index specified.
    ///
    /// To get the first 3 elements of a List:
    /// ```swift
    /// client.zrange(from: "myList", upToIndex: 3)
    /// ```
    ///
    /// To get all except the last 3 elements of a List:
    /// ```swift
    /// client.zrange(from: "myList", upToIndex: -3)
    /// ```
    ///
    /// See `zrange(from:indices:)`, `zrange(from:upToIndex:lastIndex:)`, and [https://redis.io/commands/zrange](https://redis.io/commands/zrange)
    /// - Important: This treats the SortedSet as ordered from **low** to **high**.
    ///
    /// For the inverse, see `zrevrange(from:upToIndex:includeScoresInResponse:)`.
    /// - Parameters:
    ///     - key: The key of the SortedSet to return elements from.
    ///     - index: The index of the last element to not include in the returned values.
    /// - Returns: An array of elements from the start of the SortedSet and up to the index.
    public func zrange(
        from key: RedisKey,
        upToIndex index: Int,
        includeScoresInResponse includeScores: Bool = false
    ) async throws -> [RESPValue] {
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
    /// - Returns: An array of elements found within the range specified.
    public func zrevrange(
        from key: RedisKey,
        firstIndex: Int,
        lastIndex: Int,
        includeScoresInResponse includeScores: Bool = false
    ) async throws -> [RESPValue] {
    }

    /// Gets all elements from a SortedSet within the specified inclusive bounds of 0-based indices.
    ///
    /// To get the elements at index 4 through 7:
    /// ```swift
    /// client.zrevrange(from: "mySortedSet", indices: 4...7)
    /// ```
    ///
    /// To get the last 4 elements:
    /// ```swift
    /// client.zrevrange(from: "mySortedSet", indices: (-4)...(-1))
    /// ```
    ///
    /// To get the first and last 4 elements:
    /// ```swift
    /// client.zrevrange(from: "mySortedSet", indices: (-4)...3)
    /// ```
    ///
    /// To get the first element, and the last 4:
    /// ```swift
    /// client.zrevrange(from: "mySortedSet", indices: (-4)...0))
    /// ```
    ///
    /// See [https://redis.io/commands/zrevrange](https://redis.io/commands/zrevrange)
    /// - Warning: A `ClosedRange` cannot be created where `upperBound` is less than `lowerBound`; so while Redis may support `0...-1`,
    ///     `ClosedRange` will trigger a precondition failure.
    ///
    ///     If you need such a range, use `zrevrange(from:firstIndex:lastIndex:)` instead.
    /// - Important: This treats the SortedSet as ordered from **high** to **low**.
    ///
    /// For the inverse, see `zrange(from:indices:includeScoresInResponse:)`.
    /// - Parameters:
    ///     - key: The key of the SortedSet to return elements from.
    ///     - range: The range of inclusive indices of elements to get.
    /// - Returns: An array of elements found within the range specified.
    public func zrevrange(
        from key: RedisKey,
        indices range: ClosedRange<Int>,
        includeScoresInResponse includeScores: Bool = false
    ) async throws -> [RESPValue] {
    }

    /// Gets all the elements from a SortedSet starting with the first index bound up to, but not including, the element at the last index bound.
    ///
    /// To get the elements at index 4 through 7:
    /// ```swift
    /// client.zrevrange(from: "mySortedSet", indices: 4..<8)
    /// ```
    ///
    /// To get the last 4 elements:
    /// ```swift
    /// client.zrevrange(from: "mySortedSet", indices: (-4)..<0)
    /// ```
    ///
    /// To get the first and last 4 elements:
    /// ```swift
    /// client.zrevrange(from: "mySortedSet", indices: (-4)..<4)
    /// ```
    ///
    /// To get the first element, and the last 4:
    /// ```swift
    /// client.zrevrange(from: "mySortedSet", indices: (-4)..<1)
    /// ```
    ///
    /// See [https://redis.io/commands/zrevrange](https://redis.io/commands/zrevrange)
    /// - Warning: A `Range` cannot be created where `upperBound` is less than `lowerBound`; so while Redis may support `0..<(-1)`,
    ///     `Range` will trigger a precondition failure.
    ///
    ///     If you need such a range, use `zrevrange(from:firstIndex:lastIndex:)` instead.
    /// - Important: This treats the SortedSet as ordered from **high** to **low**.
    ///
    /// For the inverse, see `zrange(from:indices:includeScoresInResponse:)`.
    /// - Parameters:
    ///     - key: The key of the SortedSet to return elements from.
    ///     - range: The range of indices (inclusive lower, exclusive upper) elements to get.
    /// - Returns: An array of elements found within the range specified.
    public func zrevrange(
        from key: RedisKey,
        indices range: Range<Int>,
        includeScoresInResponse includeScores: Bool = false
    ) async throws -> [RESPValue] {
    }

    /// Gets all elements from the index specified to the end of a SortedSet.
    ///
    /// To get all except the first 2 elements of a SortedSet:
    /// ```swift
    /// client.zrevrange(from: "mySortedSet", fromIndex: 2)
    /// ```
    ///
    /// To get the last 4 elements of a SortedSet:
    /// ```swift
    /// client.zrevrange(from: "mySortedSet", fromIndex: -4)
    /// ```
    ///
    /// See `zrevrange(from:indices:)`, `zrevrange(from:firstIndex:lastIndex:)`, and [https://redis.io/commands/zrevrange](https://redis.io/commands/zrevrange)
    /// - Important: This treats the SortedSet as ordered from **high** to **low**.
    ///
    /// For the inverse, see `zrange(from:fromIndex:includeScoresInResponse:)`.
    /// - Parameters:
    ///     - key: The key of the SortedSet to return elements from.
    ///     - index: The index of the first element that will be in the returned values.
    /// - Returns: An array of elements from the SortedSet between the index and the end.
    public func zrevrange(
        from key: RedisKey,
        fromIndex index: Int,
        includeScoresInResponse includeScores: Bool = false
    ) async throws -> [RESPValue] {
    }

    /// Gets all elements from the start of a SortedSet up to, and including, the element at the index specified.
    ///
    /// To get the first 3 elements of a SortedSet:
    /// ```swift
    /// client.zrevrange(from: "mySortedSet", throughIndex: 2)
    /// ```
    ///
    /// To get all except the last 3 elements of a SortedSet:
    /// ```swift
    /// client.zrevrange(from: "mySortedSet", throughIndex: -4)
    /// ```
    ///
    /// See `zrevrange(from:indices:)`, `zrevrange(from:firstIndex:lastIndex:)`, and [https://redis.io/commands/zrevrange](https://redis.io/commands/zrevrange)
    /// - Important: This treats the SortedSet as ordered from **high** to **low**.
    ///
    /// For the inverse, see `zrange(from:throughIndex:includeScoresInResponse:)`.
    /// - Parameters:
    ///     - key: The key of the SortedSet to return elements from.
    ///     - index: The index of the last element that will be in the returned values.
    /// - Returns: An array of elements from the start of a SortedSet to the index.
    public func zrevrange(
        from key: RedisKey,
        throughIndex index: Int,
        includeScoresInResponse includeScores: Bool = false
    ) async throws -> [RESPValue] {
    }

    /// Gets all elements from the start of a SortedSet up to, but not including, the element at the index specified.
    ///
    /// To get the first 3 elements of a List:
    /// ```swift
    /// client.zrevrange(from: "myList", upToIndex: 3)
    /// ```
    ///
    /// To get all except the last 3 elements of a List:
    /// ```swift
    /// client.zrevrange(from: "myList", upToIndex: -3)
    /// ```
    ///
    /// See `zrevrange(from:indices:)`, `zrevrange(from:upToIndex:lastIndex:)`, and [https://redis.io/commands/zrevrange](https://redis.io/commands/zrevrange)
    /// - Important: This treats the SortedSet as ordered from **high** to **low**.
    ///
    /// For the inverse, see `zrange(from:upToIndex:includeScoresInResponse:)`.
    /// - Parameters:
    ///     - key: The key of the SortedSet to return elements from.
    ///     - index: The index of the last element to not include in the returned values.
    /// - Returns: An array of elements from the start of the SortedSet and up to the index.
    public func zrevrange(
        from key: RedisKey,
        upToIndex index: Int,
        includeScoresInResponse includeScores: Bool = false
    ) async throws -> [RESPValue] {
    }
}

// MARK: Range by Score

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension RedisClient {
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
    /// - Returns: An array of elements from the SortedSet that were within the range provided, and optionally their scores.
    public func zrangebyscore(
        from key: RedisKey,
        withScoresBetween range: (min: RedisZScoreBound, max: RedisZScoreBound),
        limitBy limit: (offset: Int, count: Int)? = nil,
        includeScoresInResponse includeScores: Bool = false
    ) async throws -> [RESPValue] {
    }

    /// Gets all elements from a SortedSet whose score is within the inclusive range specified.
    ///
    /// See `RedisZScoreBound` and [https://redis.io/commands/zrangebyscore](https://redis.io/commands/zrangebyscore)
    /// - Important: This treats the SortedSet as ordered from **low** to **high**.
    ///
    /// For the inverse, see `zrevrangebyscore(from:withScores:limitBy:includeScoresInResponse:)`.
    /// - Parameters:
    ///     - key: The key of the SortedSet.
    ///     - range: The inclusive range of scores to filter elements by.
    ///     - limit: The optional offset and count of elements to query.
    ///     - includeScores: Should the response array contain the elements AND their scores? If `true`, the response array will follow the pattern [Item_1, Score_1, Item_2, ...]
    /// - Returns: An array of elements from the SortedSet that were within the range provided, and optionally their scores.
    public func zrangebyscore(
        from key: RedisKey,
        withScores range: ClosedRange<Double>,
        limitBy limit: (offset: Int, count: Int)? = nil,
        includeScoresInResponse includeScores: Bool = false
    ) async throws -> [RESPValue] {
    }

    /// Gets all elements from a SortedSet whose score is at least a minimum score up to, but not including, a max score.
    ///
    /// See `RedisZScoreBound` and [https://redis.io/commands/zrangebyscore](https://redis.io/commands/zrangebyscore)
    /// - Important: This treats the SortedSet as ordered from **low** to **high**.
    ///
    /// For the inverse, see `zrevrangebyscore(from:withScores:limitBy:includeScoresInResponse:)`.
    /// - Parameters:
    ///     - key: The key of the SortedSet.
    ///     - range: A range with an inclusive lower and exclusive upper bound of scores to filter elements by.
    ///     - limit: The optional offset and count of elements to query.
    ///     - includeScores: Should the response array contain the elements AND their scores? If `true`, the response array will follow the pattern [Item_1, Score_1, Item_2, ...]
    /// - Returns: An array of elements from the SortedSet that were within the range provided, and optionally their scores.
    public func zrangebyscore(
        from key: RedisKey,
        withScores range: Range<Double>,
        limitBy limit: (offset: Int, count: Int)? = nil,
        includeScoresInResponse includeScores: Bool = false
    ) async throws -> [RESPValue] {
    }

    /// Gets all elements from a SortedSet whose score is greater than a minimum score value.
    ///
    /// See `RedisZScoreBound` and [https://redis.io/commands/zrangebyscore](https://redis.io/commands/zrangebyscore)
    /// - Important: This treats the SortedSet as ordered from **low** to **high**.
    ///
    /// For the inverse, see `zrevrangebyscore(from:withMinimumScoreOf:limitBy:includeScoresInResponse:)`.
    /// - Parameters:
    ///     - key: The key of the SortedSet.
    ///     - range: The minimum score bound an element in the SortedSet should have to be included in the response.
    ///     - limit: The optional offset and count of elements to query.
    ///     - includeScores: Should the response array contain the elements AND their scores? If `true`, the response array will follow the pattern [Item_1, Score_1, Item_2, ...]
    /// - Returns: An array of elements from the SortedSet that were within the range provided, and optionally their scores.
    public func zrangebyscore(
        from key: RedisKey,
        withMinimumScoreOf minScore: RedisZScoreBound,
        limitBy limit: (offset: Int, count: Int)? = nil,
        includeScoresInResponse includeScores: Bool = false
    ) async throws -> [RESPValue] {
    }

    /// Gets all elements from a SortedSet whose score is less than a maximum score value.
    ///
    /// See `RedisZScoreBound` and [https://redis.io/commands/zrangebyscore](https://redis.io/commands/zrangebyscore)
    /// - Important: This treats the SortedSet as ordered from **low** to **high**.
    ///
    /// For the inverse, see `zrevrangebyscore(from:withMaximumScoreOf:limitBy:includeScoresInResponse:)`.
    /// - Parameters:
    ///     - key: The key of the SortedSet.
    ///     - range: The maximum score bound an element in the SortedSet should have to be included in the response.
    ///     - limit: The optional offset and count of elements to query.
    ///     - includeScores: Should the response array contain the elements AND their scores? If `true`, the response array will follow the pattern [Item_1, Score_1, Item_2, ...]
    /// - Returns: An array of elements from the SortedSet that were within the range provided, and optionally their scores.
    public func zrangebyscore(
        from key: RedisKey,
        withMaximumScoreOf maxScore: RedisZScoreBound,
        limitBy limit: (offset: Int, count: Int)? = nil,
        includeScoresInResponse includeScores: Bool = false
    ) async throws -> [RESPValue] {
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
    /// - Returns: An array of elements from the SortedSet that were within the range provided, and optionally their scores.
    public func zrevrangebyscore(
        from key: RedisKey,
        withScoresBetween range: (min: RedisZScoreBound, max: RedisZScoreBound),
        limitBy limit: (offset: Int, count: Int)? = nil,
        includeScoresInResponse includeScores: Bool = false
    ) async throws -> [RESPValue] {
    }

    /// Gets all elements from a SortedSet whose score is within the inclusive range specified.
    ///
    /// See `RedisZScoreBound` and [https://redis.io/commands/zrangebyscore](https://redis.io/commands/zrangebyscore)
    /// - Important: This treats the SortedSet as ordered from **high** to **low**.
    ///
    /// For the inverse, see `zrangebyscore(from:withScores:limitBy:includeScoresInResponse:)`.
    /// - Parameters:
    ///     - key: The key of the SortedSet.
    ///     - range: The inclusive range of scores to filter elements by.
    ///     - limit: The optional offset and count of elements to query.
    ///     - includeScores: Should the response array contain the elements AND their scores? If `true`, the response array will follow the pattern [Item_1, Score_1, Item_2, ...]
    /// - Returns: An array of elements from the SortedSet that were within the range provided, and optionally their scores.
    public func zrevrangebyscore(
        from key: RedisKey,
        withScores range: ClosedRange<Double>,
        limitBy limit: (offset: Int, count: Int)? = nil,
        includeScoresInResponse includeScores: Bool = false
    ) async throws -> [RESPValue] {
    }

    /// Gets all elements from a SortedSet whose score is at least a minimum score up to, but not including, a max score.
    ///
    /// See `RedisZScoreBound` and [https://redis.io/commands/zrangebyscore](https://redis.io/commands/zrangebyscore)
    /// - Important: This treats the SortedSet as ordered from **high** to **low**.
    ///
    /// For the inverse, see `zrangebyscore(from:withScores:limitBy:includeScoresInResponse:)`.
    /// - Parameters:
    ///     - key: The key of the SortedSet.
    ///     - range: A range with an inclusive lower and exclusive upper bound of scores to filter elements by.
    ///     - limit: The optional offset and count of elements to query.
    ///     - includeScores: Should the response array contain the elements AND their scores? If `true`, the response array will follow the pattern [Item_1, Score_1, Item_2, ...]
    /// - Returns: An array of elements from the SortedSet that were within the range provided, and optionally their scores.
    public func zrevrangebyscore(
        from key: RedisKey,
        withScores range: Range<Double>,
        limitBy limit: (offset: Int, count: Int)? = nil,
        includeScoresInResponse includeScores: Bool = false
    ) async throws -> [RESPValue] {
    }

    /// Gets all elements from a SortedSet whose score is greater than a minimum score value.
    ///
    /// See `RedisZScoreBound` and [https://redis.io/commands/zrangebyscore](https://redis.io/commands/zrangebyscore)
    /// - Important: This treats the SortedSet as ordered from **high** to **low**.
    ///
    /// For the inverse, see `zrangebyscore(from:withMinimumScoreOf:limitBy:includeScoresInResponse:)`.
    /// - Parameters:
    ///     - key: The key of the SortedSet.
    ///     - range: The minimum score bound an element in the SortedSet should have to be included in the response.
    ///     - limit: The optional offset and count of elements to query.
    ///     - includeScores: Should the response array contain the elements AND their scores? If `true`, the response array will follow the pattern [Item_1, Score_1, Item_2, ...]
    /// - Returns: An array of elements from the SortedSet that were within the range provided, and optionally their scores.
    public func zrevrangebyscore(
        from key: RedisKey,
        withMinimumScoreOf minScore: RedisZScoreBound,
        limitBy limit: (offset: Int, count: Int)? = nil,
        includeScoresInResponse includeScores: Bool = false
    ) async throws -> [RESPValue] {
    }

    /// Gets all elements from a SortedSet whose score is less than a maximum score value.
    ///
    /// See `RedisZScoreBound` and [https://redis.io/commands/zrangebyscore](https://redis.io/commands/zrangebyscore)
    /// - Important: This treats the SortedSet as ordered from **high** to **low**.
    ///
    /// For the inverse, see `zrangebyscore(from:withMaximumScoreOf:limitBy:includeScoresInResponse:)`.
    /// - Parameters:
    ///     - key: The key of the SortedSet.
    ///     - range: The maximum score bound an element in the SortedSet should have to be included in the response.
    ///     - limit: The optional offset and count of elements to query.
    ///     - includeScores: Should the response array contain the elements AND their scores? If `true`, the response array will follow the pattern [Item_1, Score_1, Item_2, ...]
    /// - Returns: An array of elements from the SortedSet that were within the range provided, and optionally their scores.
    public func zrevrangebyscore(
        from key: RedisKey,
        withMaximumScoreOf maxScore: RedisZScoreBound,
        limitBy limit: (offset: Int, count: Int)? = nil,
        includeScoresInResponse includeScores: Bool = false
    ) async throws -> [RESPValue] {
    }
}

// MARK: Range by Lexiographical

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension RedisClient {
    /// Gets all elements from a SortedSet whose lexiographical values are between the range specified.
    ///
    /// For example:
    /// ```
    /// // "mySortedSet" contains the values [1, 2, 3, 10] each with a score of 1
    /// client.zrangebylex(of: "mySortedSet", withValuesBetween: (.inclusive(1), .exclusive(3)))
    /// // the response resolves to [1, 10, 2]
    /// ```
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
    /// - Returns: An array of elements from the SortedSet that were within the range provided.
    @inlinable
    public func zrangebylex<Value: CustomStringConvertible>(
        from key: RedisKey,
        withValuesBetween range: (min: RedisZLexBound<Value>, max: RedisZLexBound<Value>),
        limitBy limit: (offset: Int, count: Int)? = nil
    ) async throws -> [RESPValue] {
    }

    /// Gets all elements from a SortedSet whose lexiographical value is greater than a minimum value.
    ///
    /// ```
    /// // "mySortedSet" contains the values [1, 2, 3, 10] each with a score of 1
    /// client.zrangebylex(of: "mySortedSet", withMinimumValueOf: .inclusive(1))
    /// // the response resolves to [1, 10, 2, 3]
    /// ```
    ///
    /// See `RedisZLexBound` and [https://redis.io/commands/zrangebylex](https://redis.io/commands/zrangebylex)
    /// - Warning: This assumes all elements in the SortedSet have the same score. If not, the returned elements are unspecified.
    /// - Important: This treats the SortedSet as ordered from **low** to **high**.
    ///
    /// For the inverse, see `zrevrangebylex(from:withMinimumValueOf:limitBy:)`.
    /// - Parameters:
    ///     - key: The key of the SortedSet.
    ///     - minValue: The minimum lexiographical value an element in the SortedSet should have to be included in the result set.
    ///     - limit: The optional offset and count of elements to query
    /// - Returns: An array of elements from the SortedSet above the `minValue` threshold.
    @inlinable
    public func zrangebylex<Value: CustomStringConvertible>(
        from key: RedisKey,
        withMinimumValueOf minValue: RedisZLexBound<Value>,
        limitBy limit: (offset: Int, count: Int)? = nil
    ) async throws -> [RESPValue] {
    }

    /// Gets all elements from a SortedSet whose lexiographical value is less than a maximum value.
    ///
    /// ```
    /// // "mySortedSet" contains the values [1, 2, 3, 10] each with a score of 1
    /// client.zlexcount(of: "mySortedSet", withMaximumValueOf: .exclusive(2))
    /// // the response resolves to [1, 10]
    /// ```
    ///
    /// See `RedisZLexBound` and [https://redis.io/commands/zrangebylex](https://redis.io/commands/zrangebylex)
    /// - Warning: This assumes all elements in the SortedSet have the same score. If not, the returned elements are unspecified.
    /// - Important: This treats the SortedSet as ordered from **low** to **high**.
    ///
    /// For the inverse, see `zrevrangebylex(from:withMaximumValueOf:limitBy:)`.
    /// - Parameters:
    ///     - key: The key of the SortedSet.
    ///     - minValue: The maximum lexiographical value an element in the SortedSet should have to be included in the result set.
    ///     - limit: The optional offset and count of elements to query
    /// - Returns: An array of elements from the SortedSet below the `maxValue` threshold.
    @inlinable
    public func zrangebylex<Value: CustomStringConvertible>(
        from key: RedisKey,
        withMaximumValueOf maxValue: RedisZLexBound<Value>,
        limitBy limit: (offset: Int, count: Int)? = nil
    ) async throws -> [RESPValue] {
    }

    /// Gets all elements from a SortedSet whose lexiographical values are between the range specified.
    ///
    /// For example:
    /// ```
    /// // "mySortedSet" contains the values [1, 2, 3, 10] each with a score of 1
    /// client.zrevrangebylex(of: "mySortedSet", withValuesBetween: (.inclusive(1), .exclusive(3)))
    /// // the response resolves to [2, 10 1]
    /// ```
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
    /// - Returns: An array of elements from the SortedSet that were within the range provided.
    @inlinable
    public func zrevrangebylex<Value: CustomStringConvertible>(
        from key: RedisKey,
        withValuesBetween range: (min: RedisZLexBound<Value>, max: RedisZLexBound<Value>),
        limitBy limit: (offset: Int, count: Int)? = nil
    ) async throws -> [RESPValue] {
    }

    /// Gets all elements from a SortedSet whose lexiographical value is greater than a minimum value.
    ///
    /// ```
    /// // "mySortedSet" contains the values [1, 2, 3, 10] each with a score of 1
    /// client.zrevrangebylex(of: "mySortedSet", withMinimumValueOf: .inclusive(1))
    /// // the response resolves to [3, 2, 10, 1]
    /// ```
    ///
    /// See `RedisZLexBound` and [https://redis.io/commands/zrevrangebylex](https://redis.io/commands/zrevrangebylex)
    /// - Warning: This assumes all elements in the SortedSet have the same score. If not, the returned elements are unspecified.
    /// - Important: This treats the SortedSet as ordered from **high** to **low**.
    ///
    /// For the inverse, see `zrangebylex(from:withMinimumValueOf:limitBy:)`.
    /// - Parameters:
    ///     - key: The key of the SortedSet.
    ///     - minValue: The minimum lexiographical value an element in the SortedSet should have to be included in the result set.
    ///     - limit: The optional offset and count of elements to query
    /// - Returns: An array of elements from the SortedSet above the `minValue` threshold.
    @inlinable
    public func zrevrangebylex<Value: CustomStringConvertible>(
        from key: RedisKey,
        withMinimumValueOf minValue: RedisZLexBound<Value>,
        limitBy limit: (offset: Int, count: Int)? = nil
    ) async throws -> [RESPValue] {
    }

    /// Gets all elements from a SortedSet whose lexiographical value is less than a maximum value.
    ///
    /// ```
    /// // "mySortedSet" contains the values [1, 2, 3, 10] each with a score of 1
    /// client.zrevrangebylex(of: "mySortedSet", withMaximumValueOf: .exclusive(2))
    /// // the response resolves to [10, 1]
    /// ```
    ///
    /// See `RedisZLexBound` and [https://redis.io/commands/zrevrangebylex](https://redis.io/commands/zrevrangebylex)
    /// - Warning: This assumes all elements in the SortedSet have the same score. If not, the returned elements are unspecified.
    /// - Important: This treats the SortedSet as ordered from **high** to **low**.
    ///
    /// For the inverse, see `zrangebylex(from:withMaximumValueOf:limitBy:)`.
    /// - Parameters:
    ///     - key: The key of the SortedSet.
    ///     - minValue: The maximum lexiographical value an element in the SortedSet should have to be included in the result set.
    ///     - limit: The optional offset and count of elements to query
    /// - Returns: An array of elements from the SortedSet below the `maxValue` threshold.
    @inlinable
    public func zrevrangebylex<Value: CustomStringConvertible>(
        from key: RedisKey,
        withMaximumValueOf maxValue: RedisZLexBound<Value>,
        limitBy limit: (offset: Int, count: Int)? = nil
    ) async throws -> [RESPValue] {
    }
}

// MARK: Remove

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension RedisClient {
    /// Removes the specified elements from a sorted set.
    ///
    /// See [https://redis.io/commands/zrem](https://redis.io/commands/zrem)
    /// - Parameters:
    ///     - elements: The values to remove from the sorted set.
    ///     - key: The key of the sorted set.
    /// - Returns: The number of elements removed from the set.
    @inlinable
    public func zrem<Value: RESPValueConvertible>(_ elements: [Value], from key: RedisKey) async throws -> Int {
    }

    /// Removes the specified elements from a sorted set.
    ///
    /// See [https://redis.io/commands/zrem](https://redis.io/commands/zrem)
    /// - Parameters:
    ///     - elements: The values to remove from the sorted set.
    ///     - key: The key of the sorted set.
    /// - Returns: The number of elements removed from the set.
    @inlinable
    public func zrem<Value: RESPValueConvertible>(_ elements: Value..., from key: RedisKey) async throws -> Int {
    }
}

// MARK: Remove by Lexiographical

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension RedisClient {
    /// Removes elements from a SortedSet whose lexiographical values are between the range specified.
    ///
    /// For example:
    /// ```swift
    /// // "mySortedSet" contains the values [1, 2, 3, 10] each with a score of 1.
    /// client.zremrangebylex(from: "mySortedSet", withValuesBetween: (.inclusive(10), .exclusive(3))
    /// // elements 10 and 2 were removed
    /// ```
    ///
    /// See `RedisZLexBound` and [https://redis.io/commands/zremrangebylex](https://redis.io/commands/zremrangebylex)
    /// - Warning: This assumes all elements in the SortedSet have the same score. If not, the elements removed are unspecified.
    /// - Parameters:
    ///     - key: The key of the SortedSet to remove elements from.
    ///     - range: The min and max value bounds that an element should have to be removed.
    /// - Returns: The count of elements that were removed from the SortedSet.
    @inlinable
    public func zremrangebylex<Value: CustomStringConvertible>(
        from key: RedisKey,
        withValuesBetween range: (min: RedisZLexBound<Value>, max: RedisZLexBound<Value>)
    ) async throws -> Int {
    }

    /// Removes elements from a SortedSet whose lexiographical values are greater than a minimum value.
    ///
    /// For example:
    /// ```swift
    /// // "mySortedSet" contains the values [1, 2, 3, 10] each with a score of 1.
    /// client.zremrangebylex(from: "mySortedSet", withMinimumValueOf: .inclusive(10))
    /// // elements 10, 2, and 3 are removed
    /// ```
    ///
    /// See `RedisZLexBound` and [https://redis.io/commands/zremrangebylex](https://redis.io/commands/zremrangebylex)
    /// - Warning: This assumes all elements in the SortedSet have the same score. If not, the elements removed are unspecified.
    /// - Parameters:
    ///     - key: The key of the SortedSet to remove elements from.
    ///     - minValue: The minimum lexiographical value an element in the SortedSet should have to be removed.
    /// - Returns: The count of elements that were removed from the SortedSet.
    @inlinable
    public func zremrangebylex<Value: CustomStringConvertible>(
        from key: RedisKey,
        withMinimumValueOf minValue: RedisZLexBound<Value>
    ) async throws -> Int {
    }

    /// Removes elements from a SortedSet whose lexiographical values are less than a maximum value.
    ///
    /// For example:
    /// ```swift
    /// // "mySortedSet" contains the values [1, 2, 3, 10] each with a score of 1.
    /// client.zremrangebylex(from: "mySortedSet", withMaximumValueOf: .exclusive(2))
    /// // elements 1 and 10 are removed
    /// ```
    ///
    /// See `RedisZLexBound` and [https://redis.io/commands/zremrangebylex](https://redis.io/commands/zremrangebylex)
    /// - Warning: This assumes all elements in the SortedSet have the same score. If not, the elements removed are unspecified.
    /// - Parameters:
    ///     - key: The key of the SortedSet to remove elements from.
    ///     - maxValue: The maximum lexiographical value and element in the SortedSet should have to be removed.
    /// - Returns: The count of elements that were removed from the SortedSet.
    @inlinable
    public func zremrangebylex<Value: CustomStringConvertible>(
        from key: RedisKey,
        withMaximumValueOf maxValue: RedisZLexBound<Value>
    ) async throws -> Int {
    }
}

// MARK: Remove by Rank

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension RedisClient {
    /// Removes all elements from a SortedSet within the specified inclusive bounds of 0-based indices.
    ///
    /// See [https://redis.io/commands/zremrangebyrank](https://redis.io/commands/zremrangebyrank)
    /// - Parameters:
    ///     - key: The key of the SortedSet to remove elements from.
    ///     - firstIndex: The index of the first element to remove.
    ///     - lastIndex: The index of the last element to remove.
    /// - Returns: The count of elements that were removed from the SortedSet.
    public func zremrangebyrank(from key: RedisKey, firstIndex: Int, lastIndex: Int) async throws -> Int {
    }

    /// Removes all elements from a SortedSet within the specified inclusive bounds of 0-based indices.
    ///
    /// See [https://redis.io/commands/zremrangebyrank](https://redis.io/commands/zremrangebyrank)
    /// - Warning: A `ClosedRange` cannot be created where `upperBound` is less than `lowerBound`; so while Redis may support `0...-1`,
    ///     `ClosedRange` will trigger a precondition failure.
    ///
    ///     If you need such a range, use `zremrangebyrank(from:firstIndex:lastIndex:)` instead.
    /// - Parameters:
    ///     - key: The key of the SortedSet to remove elements from.
    ///     - range: The range of inclusive indices of elements to remove.
    /// - Returns: The count of elements that were removed from the SortedSet.
    public func zremrangebyrank(from key: RedisKey, indices range: ClosedRange<Int>) async throws -> Int {
    }

    /// Removes all elements from a SortedSet starting with the first index bound up to, but not including, the element at the last index bound.
    ///
    /// See [https://redis.io/commands/zremrangebyrank](https://redis.io/commands/zremrangebyrank)
    /// - Warning: A `Range` cannot be created where `upperBound` is less than `lowerBound`; so while Redis may support `0...-1`,
    ///     `Range` will trigger a precondition failure.
    ///
    ///     If you need such a range, use `zremrangebyrank(from:firstIndex:lastIndex:)` instead.
    /// - Parameters:
    ///     - key: The key of the SortedSet to remove elements from.
    ///     - range: The range of indices (inclusive lower, exclusive upper) elements to remove.
    /// - Returns: The count of elements that were removed from the SortedSet.
    public func zremrangebyrank(from key: RedisKey, indices range: Range<Int>) async throws -> Int {
    }

    /// Removes all elements from the index specified to the end of a SortedSet.
    ///
    /// See [https://redis.io/commands/zremrangebyrank](https://redis.io/commands/zremrangebyrank)
    /// - Parameters:
    ///     - key: The key of the SortedSet to remove elements from.
    ///     - index: The index of the first element that will be removed.
    /// - Returns: The count of elements that were removed from the SortedSet.
    public func zremrangebyrank(from key: RedisKey, fromIndex index: Int) async throws -> Int {
    }

    /// Removes all elements from the start of a SortedSet up to, and including, the element at the index specified.
    ///
    /// See [https://redis.io/commands/zremrangebyrank](https://redis.io/commands/zremrangebyrank)
    /// - Parameters:
    ///     - key: The key of the SortedSet to remove elements from.
    ///     - index: The index of the last element that will be removed.
    /// - Returns: The count of elements that were removed from the SortedSet.
    public func zremrangebyrank(from key: RedisKey, throughIndex index: Int) async throws -> Int {
    }

    /// Removes all elements from the start of a SortedSet up to, but not including, the element at the index specified.
    ///
    /// See [https://redis.io/commands/zremrangebyrank](https://redis.io/commands/zremrangebyrank)
    /// - Warning: Providing an index of `0` will remove all elements from the SortedSet.
    /// - Parameters:
    ///     - key: The key of the SortedSet to remove elements from.
    ///     - index: The index of the last element to not remove.
    /// - Returns: The count of elements that were removed from the SortedSet.
    public func zremrangebyrank(from key: RedisKey, upToIndex index: Int) async throws -> Int {
    }
}

// MARK: Remove by Score

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension RedisClient {
    /// Removes elements from a SortedSet whose score is within the range specified.
    ///
    /// See `RedisZScoreBound` and [https://redis.io/commands/zremrangebyscore](https://redis.io/commands/zremrangebyscore)
    /// - Parameters:
    ///     - key: The key of the SortedSet to remove elements from.
    ///     - range: The min and max score bounds to filter elements by.
    /// - Returns: The count of elements that were removed from the SortedSet.
    public func zremrangebyscore(
        from key: RedisKey,
        withScoresBetween range: (min: RedisZScoreBound, max: RedisZScoreBound)
    ) async throws -> Int {
    }

    /// Removes elements from a SortedSet whose score is within the inclusive range specified.
    ///
    /// See `RedisZScoreBound` and [https://redis.io/commands/zremrangebyscore](https://redis.io/commands/zremrangebyscore)
    /// - Parameters:
    ///     - key: The key of the SortedSet to remove elements from.
    ///     - range: The inclusive range of scores to filter elements by.
    /// - Returns: The count of elements that were removed from the SortedSet.
    public func zremrangebyscore(from key: RedisKey, withScores range: ClosedRange<Double>) async throws -> Int {
    }

    /// Removes elements from a SortedSet whose score is at least a minimum score up to, but not including, a max score.
    ///
    /// See `RedisZScoreBound` and [https://redis.io/commands/zremrangebyscore](https://redis.io/commands/zremrangebyscore)
    /// - Parameters:
    ///     - key: The key of the SortedSet to remove elements from.
    ///     - range: A range with an inclusive lower and exclusive upper bound of scores to filter elements by.
    /// - Returns: The count of elements that were removed from the SortedSet.
    public func zremrangebyscore(from key: RedisKey, withScores range: Range<Double>) async throws -> Int {
    }

    /// Removes elements from a SortedSet whose score is greater than a minimum score value.
    ///
    /// See `RedisZScoreBound` and [https://redis.io/commands/zremrangebyscore](https://redis.io/commands/zremrangebyscore)
    /// - Parameters:
    ///     - key: The key of the SortedSet to remove elements from.
    ///     - minScore: The minimum score bound an element in the SortedSet should have to be removed.
    /// - Returns: The count of elements that were removed from the SortedSet.
    public func zremrangebyscore(from key: RedisKey, withMinimumScoreOf minScore: RedisZScoreBound) async throws -> Int {
    }

    /// Removes elements from a SortedSet whose score is less than a maximum score value.
    ///
    /// See `RedisZScoreBound` and [https://redis.io/commands/zremrangebyscore](https://redis.io/commands/zremrangebyscore)
    /// - Parameters:
    ///     - key: The key of the SortedSet to remove elements from.
    ///     - minScore: The maximum score bound an element in the SortedSet should have to be removed.
    /// - Returns: The count of elements that were removed from the SortedSet.
    public func zremrangebyscore(from key: RedisKey, withMaximumScoreOf maxScore: RedisZScoreBound) async throws -> Int {
    }
}
