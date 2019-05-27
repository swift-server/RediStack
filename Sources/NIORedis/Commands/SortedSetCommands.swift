//===----------------------------------------------------------------------===//
//
// This source file is part of the NIORedis open source project
//
// Copyright (c) 2019 NIORedis project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of NIORedis project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIO

// MARK: Static Helpers

extension RedisClient {
    @usableFromInline
    static func _mapSortedSetResponse(
        _ response: [RESPValue],
        scoreIsFirst: Bool
    ) throws -> [(RESPValue, Double)] {
        guard response.count > 0 else { return [] }

        var result: [(RESPValue, Double)] = []

        var index = 0
        repeat {
            let scoreItem = response[scoreIsFirst ? index : index + 1]

            guard let score = Double(scoreItem) else {
                throw NIORedisError.assertionFailure(message: "Unexpected response: '\(scoreItem)'")
            }

            let elementIndex = scoreIsFirst ? index + 1 : index
            result.append((response[elementIndex], score))

            index += 2
        } while (index < response.count)

        return result
    }
}

// MARK: General

extension RedisClient {
    /// Adds elements to a sorted set, assigning their score to the values provided.
    ///
    /// See [https://redis.io/commands/zadd](https://redis.io/commands/zadd)
    /// - Parameters:
    ///     - elements: A list of elements and their score to add to the sorted set.
    ///     - key: The key of the sorted set.
    ///     - options: A set of options defined by Redis for this command to execute under.
    /// - Returns: The number of elements added to the sorted set.
    @inlinable
    public func zadd(
        _ elements: [(element: RESPValueConvertible, score: Double)],
        to key: String,
        options: Set<String> = []
    ) -> EventLoopFuture<Int> {
        guard !options.contains("INCR") else {
            return self.eventLoop.makeFailedFuture(NIORedisError.unsupportedOperation(
                method: #function,
                message: "INCR option is unsupported. Use zincrby(_:element:in:) instead."
            ))
        }

        assert(options.count <= 2, "Invalid number of options provided.")
        assert(options.allSatisfy(["XX", "NX", "CH"].contains), "Unsupported option provided!")
        assert(
            !(options.contains("XX") && options.contains("NX")),
            "XX and NX options are mutually exclusive."
        )

        var args: [RESPValueConvertible] = [key] + options.map { $0 }

        for (element, score) in elements {
            args.append(score)
            args.append(element)
        }

        return send(command: "ZADD", with: args)
            .mapFromRESP()
    }

    /// Adds an element to a sorted set, assigning their score to the value provided.
    ///
    /// See [https://redis.io/commands/zadd](https://redis.io/commands/zadd)
    /// - Parameters:
    ///     - element: The element and its score to add to the sorted set.
    ///     - key: The key of the sorted set.
    ///     - options: A set of options defined by Redis for this command to execute under.
    /// - Returns: `true` if the element was added or score was updated in the sorted set.
    @inlinable
    public func zadd(
        _ element: (element: RESPValueConvertible, score: Double),
        to key: String,
        options: Set<String> = []
    ) -> EventLoopFuture<Bool> {
        return zadd([element], to: key, options: options)
            .map { return $0 == 1 }
    }

    /// Gets the number of elements in a sorted set.
    ///
    /// See [https://redis.io/commands/zcard](https://redis.io/commands/zcard)
    /// - Parameter key: The key of the sorted set.
    /// - Returns: The number of elements in the sorted set.
    @inlinable
    public func zcard(of key: String) -> EventLoopFuture<Int> {
        return send(command: "ZCARD", with: [key])
            .mapFromRESP()
    }

    /// Gets the score of the specified element in a stored set.
    ///
    /// See [https://redis.io/commands/zscore](https://redis.io/commands/zscore)
    /// - Parameters:
    ///     - element: The element in the sorted set to get the score for.
    ///     - key: The key of the sorted set.
    /// - Returns: The score of the element provided, or `nil` if the element is not found in the set or the set does not exist.
    @inlinable
    public func zscore(of element: RESPValueConvertible, in key: String) -> EventLoopFuture<Double?> {
        return send(command: "ZSCORE", with: [key, element])
            .map { return Double($0) }
    }

    /// Incrementally iterates over all elements in a sorted set.
    ///
    /// See [https://redis.io/commands/zscan](https://redis.io/commands/zscan)
    /// - Parameters:
    ///     - key: The key identifying the sorted set.
    ///     - position: The position to start the scan from.
    ///     - count: The number of elements to advance by. Redis default is 10.
    ///     - match: A glob-style pattern to filter values to be selected from the result set.
    /// - Returns: A cursor position for additional invocations with a limited collection of elements found in the sorted set with their scores.
    @inlinable
    public func zscan(
        _ key: String,
        startingFrom position: Int = 0,
        count: Int? = nil,
        matching match: String? = nil
    ) -> EventLoopFuture<(Int, [(RESPValue, Double)])> {
        return _scan(command: "ZSCAN", resultType: [RESPValue].self, key, position, count, match)
            .flatMapThrowing {
                let values = try Self._mapSortedSetResponse($0.1, scoreIsFirst: false)
                return ($0.0, values)
            }
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
    public func zrank(of element: RESPValueConvertible, in key: String) -> EventLoopFuture<Int?> {
        return send(command: "ZRANK", with: [key, element])
            .mapFromRESP()
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
    public func zrevrank(of element: RESPValueConvertible, in key: String) -> EventLoopFuture<Int?> {
        return send(command: "ZREVRANK", with: [key, element])
            .mapFromRESP()
    }
}

// MARK: Count

extension RedisClient {
    /// Returns the number of elements in a sorted set with a score within the range specified.
    ///
    /// See [https://redis.io/commands/zcount](https://redis.io/commands/zcount)
    /// - Parameters:
    ///     - key: The key of the sorted set to count.
    ///     - range: The min and max range of scores to filter for.
    /// - Returns: The number of elements in the sorted set that fit within the score range.
    @inlinable
    public func zcount(
        of key: String,
        within range: (min: String, max: String)
    ) -> EventLoopFuture<Int> {
        return send(command: "ZCOUNT", with: [key, range.min, range.max])
            .mapFromRESP()
    }

    /// Returns the number of elements in a sorted set whose lexiographical values are between the range specified.
    /// - Important: This assumes all elements in the sorted set have the same score. If not, the returned elements are unspecified.
    ///
    /// See [https://redis.io/commands/zlexcount](https://redis.io/commands/zlexcount)
    /// - Parameters:
    ///     - key: The key of the sorted set to count.
    ///     - range: The min and max range of values to filter for.
    /// - Returns: The number of elements in the sorted set that fit within the value range.
    @inlinable
    public func zlexcount(
        of key: String,
        within range: (min: String, max: String)
    ) -> EventLoopFuture<Int> {
        return send(command: "ZLEXCOUNT", with: [key, range.min, range.max])
            .mapFromRESP()
    }
}

// MARK: Pop

extension RedisClient {
    /// Removes elements from a sorted set with the lowest scores.
    ///
    /// See [https://redis.io/commands/zpopmin](https://redis.io/commands/zpopmin)
    /// - Parameters:
    ///     - key: The key identifying the sorted set in Redis.
    ///     - count: The max number of elements to pop from the set.
    /// - Returns: A list of elements popped from the sorted set with their associated score.
    @inlinable
    public func zpopmin(from key: String, max count: Int) -> EventLoopFuture<[(RESPValue, Double)]> {
        return _zpop(command: "ZPOPMIN", count, key)
    }

    /// Removes the element from a sorted set with the lowest score.
    ///
    /// See [https://redis.io/commands/zpopmin](https://redis.io/commands/zpopmin)
    /// - Parameter key: The key identifying the sorted set in Redis.
    /// - Returns: The element and its associated score that was popped from the sorted set, or `nil` if set was empty.
    @inlinable
    public func zpopmin(from key: String) -> EventLoopFuture<(RESPValue, Double)?> {
        return _zpop(command: "ZPOPMIN", nil, key)
            .map { return $0.count > 0 ? $0[0] : nil }
    }

    /// Removes elements from a sorted set with the highest scores.
    ///
    /// See [https://redis.io/commands/zpopmax](https://redis.io/commands/zpopmax)
    /// - Parameters:
    ///     - key: The key identifying the sorted set in Redis.
    ///     - count: The max number of elements to pop from the set.
    /// - Returns: A list of elements popped from the sorted set with their associated score.
    @inlinable
    public func zpopmax(from key: String, max count: Int) -> EventLoopFuture<[(RESPValue, Double)]> {
        return _zpop(command: "ZPOPMAX", count, key)
    }

    /// Removes the element from a sorted set with the highest score.
    ///
    /// See [https://redis.io/commands/zpopmax](https://redis.io/commands/zpopmax)
    /// - Parameter key: The key identifying the sorted set in Redis.
    /// - Returns: The element and its associated score that was popped from the sorted set, or `nil` if set was empty.
    @inlinable
    public func zpopmax(from key: String) -> EventLoopFuture<(RESPValue, Double)?> {
        return _zpop(command: "ZPOPMAX", nil, key)
            .map { return $0.count > 0 ? $0[0] : nil }
    }

    @usableFromInline
    func _zpop(
        command: String,
        _ count: Int?,
        _ key: String
    ) -> EventLoopFuture<[(RESPValue, Double)]> {
        var args: [RESPValueConvertible] = [key]

        if let c = count {
            guard c != 0 else { return self.eventLoop.makeSucceededFuture([]) }

            args.append(c)
        }

        return send(command: command, with: args)
            .mapFromRESP(to: [RESPValue].self)
            .flatMapThrowing { return try Self._mapSortedSetResponse($0, scoreIsFirst: true) }
    }
}

// MARK: Blocking Pop

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
    ///     - timeout: The time (in seconds) to wait. `0` means indefinitely.
    /// - Returns:
    ///     The element and its associated score that was popped from the sorted set,
    ///     or `nil` if the timeout was reached.
    @inlinable
    public func bzpopmin(
        from key: String,
        timeout: Int = 0
    ) -> EventLoopFuture<(Double, RESPValue)?> {
        return bzpopmin(from: [key], timeout: timeout)
            .map {
                guard let response = $0 else { return nil }
                return (response.1, response.2)
            }
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
    ///     - timeout: The time (in seconds) to wait. `0` means indefinitely.
    /// - Returns:
    ///     If timeout was reached, `nil`.
    ///
    ///     Otherwise, the key of the sorted set the element was removed from, the element itself,
    ///     and its associated score is returned.
    @inlinable
    public func bzpopmin(
        from keys: [String],
        timeout: Int = 0
    ) -> EventLoopFuture<(String, Double, RESPValue)?> {
        return self._bzpop(command: "BZPOPMIN", keys, timeout)
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
    ///     - timeout: The time (in seconds) to wait. `0` means indefinitely.
    /// - Returns:
    ///     The element and its associated score that was popped from the sorted set,
    ///     or `nil` if the timeout was reached.
    @inlinable
    public func bzpopmax(
        from key: String,
        timeout: Int = 0
    ) -> EventLoopFuture<(Double, RESPValue)?> {
        return self.bzpopmax(from: [key], timeout: timeout)
            .map {
                guard let response = $0 else { return nil }
                return (response.1, response.2)
            }
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
    ///     - timeout: The time (in seconds) to wait. `0` means indefinitely.
    /// - Returns:
    ///     If timeout was reached, `nil`.
    ///
    ///     Otherwise, the key of the sorted set the element was removed from, the element itself,
    ///     and its associated score is returned.
    @inlinable
    public func bzpopmax(
        from keys: [String],
        timeout: Int = 0
    ) -> EventLoopFuture<(String, Double, RESPValue)?> {
        return self._bzpop(command: "BZPOPMAX", keys, timeout)
    }

    @usableFromInline
    func _bzpop(
        command: String,
        _ keys: [String],
        _ timeout: Int
    ) -> EventLoopFuture<(String, Double, RESPValue)?> {
        let args = keys as [RESPValueConvertible] + [timeout]
        return send(command: command, with: args)
            // per the Redis docs,
            // we will receive either a nil response,
            // or an array with 3 elements in the form [Set Key, Element Score, Element Value]
            .flatMapThrowing {
                guard !$0.isNull else { return nil }
                guard let response = [RESPValue]($0) else {
                    throw NIORedisError.responseConversion(to: [RESPValue].self)
                }
                assert(response.count == 3, "Unexpected response size returned!")
                guard
                    let key = response[0].string,
                    let score = Double(response[1])
                else {
                    throw NIORedisError.assertionFailure(message: "Unexpected structure in response: \(response)")
                }
                return (key, score, response[2])
            }
    }
}

// MARK: Increment

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
    public func zincrby(
        _ amount: Double,
        element: RESPValueConvertible,
        in key: String
    ) -> EventLoopFuture<Double> {
        return send(command: "ZINCRBY", with: [key, amount, element])
            .mapFromRESP()
    }
}

// MARK: Intersect and Union

extension RedisClient {
    /// Calculates the union of two or more sorted sets and stores the result.
    /// - Note: This operation overwrites any value stored at the destination key.
    ///
    /// See [https://redis.io/commands/zunionstore](https://redis.io/commands/zunionstore)
    /// - Parameters:
    ///     - destination: The key of the new sorted set from the result.
    ///     - sources: The list of sorted set keys to treat as the source of the union.
    ///     - weights: The multiplying factor to apply to the corresponding `sources` key based on index of the two parameters.
    ///     - aggregateMethod: The method of aggregating the values of the union. Supported values are "SUM", "MIN", and "MAX".
    /// - Returns: The number of elements in the new sorted set.
    @inlinable
    public func zunionstore(
        as destination: String,
        sources: [String],
        weights: [Int]? = nil,
        aggregateMethod aggregate: String? = nil
    ) -> EventLoopFuture<Int> {
        return _zopstore(command: "ZUNIONSTORE", sources, destination, weights, aggregate)
    }

    /// Calculates the intersection of two or more sorted sets and stores the result.
    /// - Note: This operation overwrites any value stored at the destination key.
    ///
    /// See [https://redis.io/commands/zinterstore](https://redis.io/commands/zinterstore)
    /// - Parameters:
    ///     - destination: The key of the new sorted set from the result.
    ///     - sources: The list of sorted set keys to treat as the source of the intersection.
    ///     - weights: The multiplying factor to apply to the corresponding `sources` key based on index of the two parameters.
    ///     - aggregateMethod: The method of aggregating the values of the intersection. Supported values are "SUM", "MIN", and "MAX".
    /// - Returns: The number of elements in the new sorted set.
    @inlinable
    public func zinterstore(
        as destination: String,
        sources: [String],
        weights: [Int]? = nil,
        aggregateMethod aggregate: String? = nil
    ) -> EventLoopFuture<Int> {
        return _zopstore(command: "ZINTERSTORE", sources, destination, weights, aggregate)
    }

    @usableFromInline
    func _zopstore(
        command: String,
        _ sources: [String],
        _ destination: String,
        _ weights: [Int]?,
        _ aggregate: String?) -> EventLoopFuture<Int>
    {
        assert(sources.count > 0, "At least 1 source key should be provided.")

        var args: [RESPValueConvertible] = [destination, sources.count] + sources

        if let w = weights {
            assert(w.count > 0, "When passing a value for 'weights', at least 1 value should be provided.")
            assert(w.count <= sources.count, "Weights should be no larger than the amount of source keys.")

            args.append("WEIGHTS")
            args.append(contentsOf: w)
        }

        if let a = aggregate {
            assert(a == "SUM" || a == "MIN" || a == "MAX", "Aggregate method provided is unsupported.")

            args.append("AGGREGATE")
            args.append(a)
        }

        return send(command: command, with: args)
            .mapFromRESP()
    }
}

// MARK: Range

extension RedisClient {
    /// Gets the specified range of elements in a sorted set.
    /// - Note: This treats the ordered set as ordered from low to high.
    ///
    /// For the inverse, see `zrevrange(within:from:withScores:)`.
    ///
    /// See [https://redis.io/commands/zrange](https://redis.io/commands/zrange)
    /// - Parameters:
    ///     - range: The start and stop 0-based indices of the range of elements to include.
    ///     - key: The key of the sorted set to search.
    ///     - withScores: Should the list contain the elements AND their scores? [Item_1, Score_1, Item_2, ...]
    /// - Returns: A list of elements from the sorted set that were within the range provided, and optionally their scores.
    @inlinable
    public func zrange(
        within range: (start: Int, stop: Int),
        from key: String,
        withScores: Bool = false
    ) -> EventLoopFuture<[RESPValue]> {
        return _zrange(command: "ZRANGE", key, range.start, range.stop, withScores)
    }

    /// Gets the specified range of elements in a sorted set.
    /// - Note: This treats the ordered set as ordered from high to low.
    ///
    /// For the inverse, see `zrange(within:from:withScores:)`.
    ///
    /// See [https://redis.io/commands/zrevrange](https://redis.io/commands/zrevrange)
    /// - Parameters:
    ///     - range: The start and stop 0-based indices of the range of elements to include.
    ///     - key: The key of the sorted set to search.
    ///     - withScores: Should the list contain the elements AND their scores? [Item_1, Score_1, Item_2, ...]
    /// - Returns: A list of elements from the sorted set that were within the range provided, and optionally their scores.
    @inlinable
    public func zrevrange(
        within range: (start: Int, stop: Int),
        from key: String,
        withScores: Bool = false
    ) -> EventLoopFuture<[RESPValue]> {
        return _zrange(command: "ZREVRANGE", key, range.start, range.stop, withScores)
    }

    @usableFromInline
    func _zrange(
        command: String,
        _ key: String,
        _ start: Int,
        _ stop: Int,
        _ withScores: Bool
    ) -> EventLoopFuture<[RESPValue]> {
        var args: [RESPValueConvertible] = [key, start, stop]

        if withScores { args.append("WITHSCORES") }

        return send(command: command, with: args)
            .mapFromRESP()
    }
}

// MARK: Range by Score

extension RedisClient {
    /// Gets elements from a sorted set whose score fits within the range specified.
    /// - Note: This treats the ordered set as ordered from low to high.
    ///
    /// For the inverse, see `zrevrangebyscore(within:from:withScores:limitBy:)`.
    ///
    /// See [https://redis.io/commands/zrangebyscore](https://redis.io/commands/zrangebyscore)
    /// - Parameters:
    ///     - range: The range of min and max scores to filter elements by.
    ///     - key: The key of the sorted set to search.
    ///     - withScores: Should the list contain the elements AND their scores? [Item_1, Score_1, Item_2, ...]
    ///     - limit: The optional offset and count of elements to query.
    /// - Returns: A list of elements from the sorted set that were within the range provided, and optionally their scores.
    @inlinable
    public func zrangebyscore(
        within range: (min: String, max: String),
        from key: String,
        withScores: Bool = false,
        limitBy limit: (offset: Int, count: Int)? = nil
    ) -> EventLoopFuture<[RESPValue]> {
        return _zrangebyscore(command: "ZRANGEBYSCORE", key, range, withScores, limit)
    }

    /// Gets elements from a sorted set whose score fits within the range specified.
    /// - Note: This treats the ordered set as ordered from high to low.
    ///
    /// For the inverse, see `zrangebyscore(within:from:withScores:limitBy:)`.
    ///
    /// See [https://redis.io/commands/zrevrangebyscore](https://redis.io/commands/zrevrangebyscore)
    /// - Parameters:
    ///     - range: The range of min and max scores to filter elements by.
    ///     - key: The key of the sorted set to search.
    ///     - withScores: Should the list contain the elements AND their scores? [Item_1, Score_1, Item_2, ...]
    ///     - limit: The optional offset and count of elements to query.
    /// - Returns: A list of elements from the sorted set that were within the range provided, and optionally their scores.
    @inlinable
    public func zrevrangebyscore(
        within range: (min: String, max: String),
        from key: String,
        withScores: Bool = false,
        limitBy limit: (offset: Int, count: Int)? = nil
    ) -> EventLoopFuture<[RESPValue]> {
        return _zrangebyscore(command: "ZREVRANGEBYSCORE", key, (range.max, range.min), withScores, limit)
    }

    @usableFromInline
    func _zrangebyscore(
        command: String,
        _ key: String,
        _ range: (min: String, max: String),
        _ withScores: Bool,
        _ limit: (offset: Int, count: Int)?
    ) -> EventLoopFuture<[RESPValue]> {
        var args: [RESPValueConvertible] = [key, range.min, range.max]

        if withScores { args.append("WITHSCORES") }

        if let l = limit {
            args.append("LIMIT")
            args.append([l.offset, l.count])
        }

        return send(command: command, with: args)
            .mapFromRESP()
    }
}

// MARK: Range by Lexiographical

extension RedisClient {
    /// Gets elements from a sorted set whose lexiographical values are between the range specified.
    /// - Important: This assumes all elements in the sorted set have the same score. If not, the returned elements are unspecified.
    /// - Note: This treats the ordered set as ordered from low to high.
    ///
    /// For the inverse, see `zrevrangebylex(within:from:limitBy:)`.
    ///
    /// See [https://redis.io/commands/zrangebylex](https://redis.io/commands/zrangebylex)
    /// - Parameters:
    ///     - range: The value range to filter elements by.
    ///     - key: The key of the sorted set to search.
    ///     - limit: The optional offset and count of elements to query.
    /// - Returns: A list of elements from the sorted set that were within the range provided.
    @inlinable
    public func zrangebylex(
        within range: (min: String, max: String),
        from key: String,
        limitBy limit: (offset: Int, count: Int)? = nil
    ) -> EventLoopFuture<[RESPValue]> {
        return _zrangebylex(command: "ZRANGEBYLEX", key, range, limit)
    }

    /// Gets elements from a sorted set whose lexiographical values are between the range specified.
    /// - Important: This assumes all elements in the sorted set have the same score. If not, the returned elements are unspecified.
    /// - Note: This treats the ordered set as ordered from high to low.
    ///
    /// For the inverse, see `zrangebylex(within:from:limitBy:)`.
    ///
    /// See [https://redis.io/commands/zrevrangebylex](https://redis.io/commands/zrevrangebylex)
    /// - Parameters:
    ///     - range: The value range to filter elements by.
    ///     - key: The key of the sorted set to search.
    ///     - limit: The optional offset and count of elements to query.
    /// - Returns: A list of elements from the sorted set that were within the range provided.
    @inlinable
    public func zrevrangebylex(
        within range: (min: String, max: String),
        from key: String,
        limitBy limit: (offset: Int, count: Int)? = nil
    ) -> EventLoopFuture<[RESPValue]> {
        return _zrangebylex(command: "ZREVRANGEBYLEX", key, (range.max, range.min), limit)
    }

    @usableFromInline
    func _zrangebylex(
        command: String,
        _ key: String,
        _ range: (min: String, max: String),
        _ limit: (offset: Int, count: Int)?
    ) -> EventLoopFuture<[RESPValue]> {
        var args: [RESPValueConvertible] = [key, range.min, range.max]

        if let l = limit {
            args.append("LIMIT")
            args.append(contentsOf: [l.offset, l.count])
        }

        return send(command: command, with: args)
            .mapFromRESP()
    }
}

// MARK: Remove

extension RedisClient {
    /// Removes the specified elements from a sorted set.
    ///
    /// See [https://redis.io/commands/zrem](https://redis.io/commands/zrem)
    /// - Parameters:
    ///     - elements: The values to remove from the sorted set.
    ///     - key: The key of the sorted set.
    /// - Returns: The number of elements removed from the set.
    @inlinable
    public func zrem(_ elements: [RESPValueConvertible], from key: String) -> EventLoopFuture<Int> {
        guard elements.count > 0 else { return self.eventLoop.makeSucceededFuture(0) }

        return send(command: "ZREM", with: [key] + elements)
            .mapFromRESP()
    }

    /// Removes elements from a sorted set whose lexiographical values are between the range specified.
    /// - Important: This assumes all elements in the sorted set have the same score. If not, the elements selected are unspecified.
    ///
    /// See [https://redis.io/commands/zremrangebylex](https://redis.io/commands/zremrangebylex)
    /// - Parameters:
    ///     - range: The value range to filter for elements to remove.
    ///     - key: The key of the sorted set to search.
    /// - Returns: The number of elements removed from the sorted set.
    @inlinable
    public func zremrangebylex(
        within range: (min: String, max: String),
        from key: String
    ) -> EventLoopFuture<Int> {
        return send(command: "ZREMRANGEBYLEX", with: [key, range.min, range.max])
            .mapFromRESP()
    }

    /// Removes elements from a sorted set whose index is between the provided range.
    ///
    /// See [https://redis.io/commands/zremrangebyrank](https://redis.io/commands/zremrangebyrank)
    /// - Parameters:
    ///     - range: The index range of elements to remove.
    ///     - key: The key of the sorted set to search.
    /// - Returns: The number of elements removed from the sorted set.
    @inlinable
    public func zremrangebyrank(
        within range: (start: Int, stop: Int),
        from key: String
    ) -> EventLoopFuture<Int> {
        return send(command: "ZREMRANGEBYRANK", with: [key, range.start, range.stop])
            .mapFromRESP()
    }

    /// Removes elements from a sorted set whose score is within the range specified.
    ///
    /// See [https://redis.io/commands/zremrangebyscore](https://redis.io/commands/zremrangebyscore)
    /// - Parameters:
    ///     - range: The score range to filter for elements to remove.
    ///     - key: The key of the sorted set to search.
    /// - Returns: The number of elements removed from the sorted set.
    @inlinable
    public func zremrangebyscore(
        within range: (min: String, max: String),
        from key: String
    ) -> EventLoopFuture<Int> {
        return send(command: "ZREMRANGEBYSCORE", with: [key, range.min, range.max])
            .mapFromRESP()
    }
}
