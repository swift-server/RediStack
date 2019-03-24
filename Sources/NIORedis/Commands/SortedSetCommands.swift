import NIO

// MARK: Static Helpers

extension RedisCommandExecutor {
    @usableFromInline
    static func _mapSortedSetResponse(_ response: [RESPValue], scoreIsFirst: Bool) throws -> [(RESPValue, Double)] {
        guard response.count > 0 else { return [] }

        var result: [(RESPValue, Double)] = []

        var index = 0
        repeat {
            let scoreItem = response[scoreIsFirst ? index : index + 1]

            guard let score = Double(scoreItem) else {
                throw RedisError(identifier: #function, reason: "Unexpected response \"\(scoreItem)\"")
            }

            let memberIndex = scoreIsFirst ? index + 1 : index
            result.append((response[memberIndex], score))

            index += 2
        } while (index < response.count)

        return result
    }
}

// MARK: General

extension RedisCommandExecutor {
    /// Adds elements to a sorted set, assigning their score to the values provided.
    ///
    /// See [https://redis.io/commands/zadd](https://redis.io/commands/zadd)
    /// - Parameters:
    ///     - items: A list of elements and their score to add to the sorted set.
    ///     - to: The key of the sorted set.
    ///     - options: A set of options defined by Redis for this command to execute under.
    /// - Returns: The number of elements added to the sorted set.
    @inlinable
    public func zadd(
        _ items: [(element: RESPValueConvertible, score: Double)],
        to key: String,
        options: Set<String> = []) -> EventLoopFuture<Int>
    {
        guard !options.contains("INCR") else {
            return eventLoop.makeFailedFuture(RedisError(identifier: #function, reason: "INCR option is unsupported. Use zincrby(_:member:by:) instead."))
        }

        assert(options.count <= 2, "Invalid number of options provided.")
        assert(options.allSatisfy(["XX", "NX", "CH"].contains), "Unsupported option provided!")
        assert(
            !(options.contains("XX") && options.contains("NX")),
            "XX and NX options are mutually exclusive."
        )

        var args: [RESPValueConvertible] = [key] + options.map { $0 }

        for (element, score) in items {
            switch score {
            case .infinity: args.append("+inf")
            case -.infinity: args.append("-inf")
            default: args.append(score)
            }

            args.append(element)
        }

        return send(command: "ZADD", with: args)
            .mapFromRESP()
    }

    /// Adds an element to a sorted set, assigning their score to the value provided.
    ///
    /// See [https://redis.io/commands/zadd](https://redis.io/commands/zadd)
    /// - Parameters:
    ///     - item: The element and its score to add to the sorted set.
    ///     - to: The key of the sorted set.
    ///     - options: A set of options defined by Redis for this command to execute under.
    /// - Returns: `true` if the element was added or score was updated in the sorted set.
    @inlinable
    public func zadd(
        _ item: (element: RESPValueConvertible, score: Double),
        to key: String,
        options: Set<String> = []) -> EventLoopFuture<Bool>
    {
        return zadd([item], to: key, options: options)
            .map { return $0 == 1 }
    }

    /// Returns the number of elements in a sorted set.
    ///
    /// See [https://redis.io/commands/zcard](https://redis.io/commands/zcard)
    /// - Parameter of: The key of the sorted set.
    /// - Returns: The number of elements in the sorted set.
    @inlinable
    public func zcard(of key: String) -> EventLoopFuture<Int> {
        return send(command: "ZCARD", with: [key])
            .mapFromRESP()
    }

    /// Returns the score of the specified member in a stored set.
    ///
    /// See [https://redis.io/commands/zscore](https://redis.io/commands/zscore)
    /// - Parameters:
    ///     - of: The element in the sorted set to get the score for.
    ///     - storedAt: The key of the sorted set.
    /// - Returns: The score of the element provided.
    @inlinable
    public func zscore(of member: RESPValueConvertible, storedAt key: String) -> EventLoopFuture<Double?> {
        return send(command: "ZSCORE", with: [key, member])
            .map { return Double($0) }
    }

    /// Incrementally iterates over all fields in a sorted set.
    ///
    /// See [https://redis.io/commands/zscan](https://redis.io/commands/zscan)
    /// - Parameters:
    ///     - key: The key identifying the sorted set.
    ///     - startingFrom: The position to start the scan from.
    ///     - count: The number of elements to advance by. Redis default is 10.
    ///     - matching: A glob-style pattern to filter values to be selected from the result set.
    /// - Returns: A cursor position for additional invocations with a limited collection of values and their scores.
    @inlinable
    public func zscan(
        _ key: String,
        startingFrom position: Int = 0,
        count: Int? = nil,
        matching match: String? = nil) -> EventLoopFuture<(Int, [(RESPValue, Double)])>
    {
        return _scan(command: "ZSCAN", resultType: [RESPValue].self, key, position, count, match)
            .flatMapThrowing {
                let values = try Self._mapSortedSetResponse($0.1, scoreIsFirst: false)
                return ($0.0, values)
            }
    }
}

// MARK: Rank

extension RedisCommandExecutor {
    /// Returns the rank (index) of the specified element in a sorted set.
    /// - Note: This treats the ordered set as ordered from low to high.
    /// For the inverse, see `zrevrank(of:storedAt:)`.
    ///
    /// See [https://redis.io/commands/zrank](https://redis.io/commands/zrank)
    /// - Parameters:
    ///     - of: The element in the sorted set to search for.
    ///     - storedAt: The key of the sorted set to search.
    /// - Returns: The index of the element, or `nil` if the key was not found.
    @inlinable
    public func zrank(of member: RESPValueConvertible, storedAt key: String) -> EventLoopFuture<Int?> {
        return send(command: "ZRANK", with: [key, member])
            .mapFromRESP()
    }

    /// Returns the rank (index) of the specified element in a sorted set.
    /// - Note: This treats the ordered set as ordered from high to low.
    /// For the inverse, see `zrank(of:storedAt:)`.
    ///
    /// See [https://redis.io/commands/zrevrank](https://redis.io/commands/zrevrank)
    /// - Parameters:
    ///     - of: The element in the sorted set to search for.
    ///     - storedAt: The key of the sorted set to search.
    /// - Returns: The index of the element, or `nil` if the key was not found.
    @inlinable
    public func zrevrank(of member: RESPValueConvertible, storedAt key: String) -> EventLoopFuture<Int?> {
        return send(command: "ZREVRANK", with: [key, member])
            .mapFromRESP()
    }
}

// MARK: Count

extension RedisCommandExecutor {
    /// Returns the number of elements in a sorted set with a score within the range specified.
    ///
    /// See [https://redis.io/commands/zcount](https://redis.io/commands/zcount)
    /// - Parameters:
    ///     - of: The key of the sorted set to count.
    ///     - within: The min and max range of scores to filter for.
    /// - Returns: The number of elements in the sorted set that fit within the score range.
    @inlinable
    public func zcount(of key: String, within range: (min: String, max: String)) -> EventLoopFuture<Int> {
        return send(command: "ZCOUNT", with: [key, range.min, range.max])
            .mapFromRESP()
    }

    /// Returns the number of elements in a sorted set whose lexiographical values are between the range specified.
    /// - Important: This assumes all elements in the sorted set have the same score. If not, the returned elements are unspecified.
    ///
    /// See [https://redis.io/commands/zlexcount](https://redis.io/commands/zlexcount)
    /// - Parameters:
    ///     - of: The key of the sorted set to count.
    ///     - within: The min and max range of values to filter for.
    /// - Returns: The number of elements in the sorted set that fit within the value range.
    @inlinable
    public func zlexcount(of key: String, within range: (min: String, max: String)) -> EventLoopFuture<Int> {
        return send(command: "ZLEXCOUNT", with: [key, range.min, range.max])
            .mapFromRESP()
    }
}

// MARK: Pop

extension RedisCommandExecutor {
    /// Removes members from a sorted set with the lowest scores.
    ///
    /// See [https://redis.io/commands/zpopmin](https://redis.io/commands/zpopmin)
    /// - Parameters:
    ///     - count: The max number of elements to pop from the set.
    ///     - from: The key identifying the sorted set in Redis.
    /// - Returns: A list of members popped from the sorted set with their associated score.
    @inlinable
    public func zpopmin(_ count: Int, from key: String) -> EventLoopFuture<[(RESPValue, Double)]> {
        return _zpop(command: "ZPOPMIN", count, key)
    }

    /// Removes a member from a sorted set with the lowest score.
    ///
    /// See [https://redis.io/commands/zpopmin](https://redis.io/commands/zpopmin)
    /// - Parameters:
    ///     - from: The key identifying the sorted set in Redis.
    /// - Returns: The element and its associated score that was popped from the sorted set, or `nil` if set was empty.
    @inlinable
    public func zpopmin(from key: String) -> EventLoopFuture<(RESPValue, Double)?> {
        return _zpop(command: "ZPOPMIN", nil, key)
            .map { return $0.count > 0 ? $0[0] : nil }
    }

    /// Removes members from a sorted set with the highest scores.
    ///
    /// See [https://redis.io/commands/zpopmax](https://redis.io/commands/zpopmax)
    /// - Parameters:
    ///     - count: The max number of elements to pop from the set.
    ///     - from: The key identifying the sorted set in Redis.
    /// - Returns: A list of members popped from the sorted set with their associated score.
    @inlinable
    public func zpopmax(_ count: Int, from key: String) -> EventLoopFuture<[(RESPValue, Double)]> {
        return _zpop(command: "ZPOPMAX", count, key)
    }

    /// Removes a member from a sorted set with the highest score.
    ///
    /// See [https://redis.io/commands/zpopmax](https://redis.io/commands/zpopmax)
    /// - Parameters:
    ///     - from: The key identifying the sorted set in Redis.
    /// - Returns: The element and its associated score that was popped from the sorted set, or `nil` if set was empty.
    @inlinable
    public func zpopmax(from key: String) -> EventLoopFuture<(RESPValue, Double)?> {
        return _zpop(command: "ZPOPMAX", nil, key)
            .map { return $0.count > 0 ? $0[0] : nil }
    }

    @usableFromInline
    func _zpop(command: String, _ count: Int?, _ key: String) -> EventLoopFuture<[(RESPValue, Double)]> {
        var args: [RESPValueConvertible] = [key]

        if let c = count { args.append(c) }

        return send(command: command, with: args)
            .mapFromRESP(to: [RESPValue].self)
            .flatMapThrowing { return try Self._mapSortedSetResponse($0, scoreIsFirst: true) }
    }
}

// MARK: Increment

extension RedisCommandExecutor {
    /// Increments the score of the specified member in a sorted set.
    ///
    /// See [https://redis.io/commands/zincrby](https://redis.io/commands/zincrby)
    /// - Parameters:
    ///     - key: The key of the sorted set.
    ///     - member: The element to increment.
    ///     - by: The amount to increment this element's score by.
    /// - Returns: The new score of the member.
    @inlinable
    public func zincrby(_ key: String, member: RESPValueConvertible, by amount: Int) -> EventLoopFuture<Double> {
        return send(command: "ZINCRBY", with: [key, amount, member])
            .mapFromRESP()
    }

    /// Increments the score of the specified member in a sorted set.
    ///
    /// See [https://redis.io/commands/zincrby](https://redis.io/commands/zincrby)
    /// - Parameters:
    ///     - key: The key of the sorted set.
    ///     - member: The element to increment.
    ///     - by: The amount to increment this element's score by.
    /// - Returns: The new score of the member.
    @inlinable
    public func zincrby(_ key: String, member: RESPValueConvertible, by amount: Double) -> EventLoopFuture<Double> {
        return send(command: "ZINCRBY", with: [key, amount, member])
            .mapFromRESP()
    }
}

// MARK: Intersect and Union

extension RedisCommandExecutor {
    /// Computes a new sorted set as a union between all provided source sorted sets and stores the result at the key desired.
    /// - Note: This operation overwrites any value stored at the destination key.
    ///
    /// See [https://redis.io/commands/zunionstore](https://redis.io/commands/zunionstore)
    /// - Parameters:
    ///     - sources: The list of sorted set keys to treat as the source of the union.
    ///     - to: The key to store the union sorted set at.
    ///     - weights: The multiplying factor to apply to the corresponding `sources` key based on index of the two parameters.
    ///     - aggregateMethod: The method of aggregating the values of the union. Supported values are "SUM", "MIN", and "MAX".
    /// - Returns: The number of members in the new sorted set.
    @inlinable
    public func zunionstore(
        _ sources: [String],
        to destination: String,
        weights: [Int]? = nil,
        aggregateMethod aggregate: String? = nil) -> EventLoopFuture<Int>
    {
        return _zopstore(command: "ZUNIONSTORE", sources, destination, weights, aggregate)
    }

    /// Computes a new sorted set as an intersection between all provided source sorted sets and stores the result at the key desired.
    /// - Note: This operation overwrites any value stored at the destination key.
    ///
    /// See [https://redis.io/commands/zinterstore](https://redis.io/commands/zinterstore)
    /// - Parameters:
    ///     - sources: The list of sorted set keys to treat as the source of the intersection.
    ///     - to: The key to store the intersected sorted set at.
    ///     - weights: The multiplying factor to apply to the corresponding `sources` key based on index of the two parameters.
    ///     - aggregateMethod: The method of aggregating the values of the intersection. Supported values are "SUM", "MIN", and "MAX".
    /// - Returns: The number of members in the new sorted set.
    @inlinable
    public func zinterstore(
        _ sources: [String],
        to destination: String,
        weights: [Int]? = nil,
        aggregateMethod aggregate: String? = nil) -> EventLoopFuture<Int>
    {
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

extension RedisCommandExecutor {
    /// Returns the specified range of elements in a sorted set.
    /// - Note: This treats the ordered set as ordered from low to high.
    /// For the inverse, see `zrevrange(of:startIndex:endIndex:withScores:)`.
    ///
    /// See [https://redis.io/commands/zrange](https://redis.io/commands/zrange)
    /// - Parameters:
    ///     - withinIndices: The start and stop 0-based indices of the range of elements to include.
    ///     - from: The key of the sorted set to search.
    ///     - withScores: Should the list contain the items AND their scores? [Item_1, Score_1, Item_2, ...]
    /// - Returns: A list of elements from the sorted set that were within the range provided, and optionally their scores.
    @inlinable
    public func zrange(
        withinIndices range: (start: Int, stop: Int),
        from key: String,
        withScores: Bool = false) -> EventLoopFuture<[RESPValue]>
    {
        return _zrange(command: "ZRANGE", key, range.start, range.stop, withScores)
    }

    /// Returns the specified range of elements in a sorted set.
    /// - Note: This treats the ordered set as ordered from high to low.
    /// For the inverse, see `zrange(of:startIndex:endIndex:withScores:)`.
    ///
    /// See [https://redis.io/commands/zrevrange](https://redis.io/commands/zrevrange)
    /// - Parameters:
    ///     - withinIndices: The start and stop 0-based indices of the range of elements to include.
    ///     - from: The key of the sorted set to search.
    ///     - withScores: Should the list contain the items AND their scores? [Item_1, Score_1, Item_2, ...]
    /// - Returns: A list of elements from the sorted set that were within the range provided, and optionally their scores.
    @inlinable
    public func zrevrange(
        withinIndices range: (start: Int, stop: Int),
        from key: String,
        withScores: Bool = false) -> EventLoopFuture<[RESPValue]>
    {
        return _zrange(command: "ZREVRANGE", key, range.start, range.stop, withScores)
    }

    @usableFromInline
    func _zrange(command: String, _ key: String, _ start: Int, _ stop: Int, _ withScores: Bool) -> EventLoopFuture<[RESPValue]> {
        var args: [RESPValueConvertible] = [key, start, stop]

        if withScores { args.append("WITHSCORES") }

        return send(command: command, with: args)
            .mapFromRESP()
    }
}

// MARK: Range by Score

extension RedisCommandExecutor {
    /// Returns elements from a sorted set whose score fits within the range specified.
    /// - Note: This treats the ordered set as ordered from low to high.
    /// For the inverse, see `zrevrangebyscore(of:within:withScores:limitBy:)`.
    ///
    /// See [https://redis.io/commands/zrangebyscore](https://redis.io/commands/zrangebyscore)
    /// - Parameters:
    ///     - within: The range of min and max scores to filter elements by.
    ///     - from: The key of the sorted set to search.
    ///     - withScores: Should the list contain the items AND their scores? [Item_1, Score_1, Item_2, ...]
    ///     - limitBy: The optional offset and count of items to query.
    /// - Returns: A list of elements from the sorted set that were within the range provided, and optionally their scores.
    @inlinable
    public func zrangebyscore(
        within range: (min: String, max: String),
        from key: String,
        withScores: Bool = false,
        limitBy limit: (offset: Int, count: Int)? = nil) -> EventLoopFuture<[RESPValue]>
    {
        return _zrangebyscore(command: "ZRANGEBYSCORE", key, range, withScores, limit)
    }

    /// Returns elements from a sorted set whose score fits within the range specified.
    /// - Note: This treats the ordered set as ordered from high to low.
    /// For the inverse, see `zrangebyscore(of:within:withScores:limitBy:)`.
    ///
    /// See [https://redis.io/commands/zrevrangebyscore](https://redis.io/commands/zrevrangebyscore)
    /// - Parameters:
    ///     - within: The range of min and max scores to filter elements by.
    ///     - from: The key of the sorted set to search.
    ///     - withScores: Should the list contain the items AND their scores? [Item_1, Score_1, Item_2, ...]
    ///     - limitBy: The optional offset and count of items to query.
    /// - Returns: A list of elements from the sorted set that were within the range provided, and optionally their scores.
    @inlinable
    public func zrevrangebyscore(
        within range: (min: String, max: String),
        from key: String,
        withScores: Bool = false,
        limitBy limit: (offset: Int, count: Int)? = nil) -> EventLoopFuture<[RESPValue]>
    {
        return _zrangebyscore(command: "ZREVRANGEBYSCORE", key, (range.max, range.min), withScores, limit)
    }

    @usableFromInline
    func _zrangebyscore(command: String, _ key: String, _ range: (min: String, max: String), _ withScores: Bool, _ limit: (offset: Int, count: Int)?) -> EventLoopFuture<[RESPValue]> {
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

extension RedisCommandExecutor {
    /// Returns elements from a sorted set whose lexiographical values are between the range specified.
    /// - Important: This assumes all elements in the sorted set have the same score. If not, the returned elements are unspecified.
    /// - Note: This treats the ordered set as ordered from low to high.
    /// For the inverse, see `zrevrangebylex(of:within:limitBy:)`.
    ///
    /// See [https://redis.io/commands/zrangebylex](https://redis.io/commands/zrangebylex)
    /// - Parameters:
    ///     - within: The value range to filter elements by.
    ///     - from: The key of the sorted set to search.
    ///     - limitBy: The optional offset and count of items to query.
    /// - Returns: A list of elements from the sorted set that were within the range provided.
    @inlinable
    public func zrangebylex(
        within range: (min: String, max: String),
        from key: String,
        limitBy limit: (offset: Int, count: Int)? = nil) -> EventLoopFuture<[RESPValue]>
    {
        return _zrangebylex(command: "ZRANGEBYLEX", key, range, limit)
    }

    /// Returns elements from a sorted set whose lexiographical values are between the range specified.
    /// - Important: This assumes all elements in the sorted set have the same score. If not, the returned elements are unspecified.
    /// - Note: This treats the ordered set as ordered from high to low.
    /// For the inverse, see `zrangebylex(of:within:limitBy:)`.
    ///
    /// See [https://redis.io/commands/zrevrangebylex](https://redis.io/commands/zrevrangebylex)
    /// - Parameters:
    ///     - within: The value range to filter elements by.
    ///     - from: The key of the sorted set to search.
    ///     - limitBy: The optional offset and count of items to query.
    /// - Returns: A list of elements from the sorted set that were within the range provided.
    @inlinable
    public func zrevrangebylex(
        within range: (min: String, max: String),
        from key: String,
        limitBy limit: (offset: Int, count: Int)? = nil) -> EventLoopFuture<[RESPValue]>
    {
        return _zrangebylex(command: "ZREVRANGEBYLEX", key, (range.max, range.min), limit)
    }

    @usableFromInline
    func _zrangebylex(command: String, _ key: String, _ range: (min: String, max: String), _ limit: (offset: Int, count: Int)?) -> EventLoopFuture<[RESPValue]> {
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

extension RedisCommandExecutor {
    /// Removes the specified items from a sorted set.
    ///
    /// See [https://redis.io/commands/zrem](https://redis.io/commands/zrem)
    /// - Parameters:
    ///     - items: The values to remove from the sorted set.
    ///     - from: The key of the sorted set.
    /// - Returns: The number of items removed from the set.
    @inlinable
    public func zrem(_ items: [RESPValueConvertible], from key: String) -> EventLoopFuture<Int> {
        assert(items.count > 0, "At least 1 item should be provided.")

        return send(command: "ZREM", with: [key] + items)
            .mapFromRESP()
    }

    /// Removes elements from a sorted set whose lexiographical values are between the range specified.
    /// - Important: This assumes all elements in the sorted set have the same score. If not, the elements selected are unspecified.
    ///
    /// See [https://redis.io/commands/zremrangebylex](https://redis.io/commands/zremrangebylex)
    /// - Parameters:
    ///     - within: The value range to filter for elements to remove.
    ///     - from: The key of the sorted set to search.
    /// - Returns: The number of elements removed from the sorted set.
    @inlinable
    public func zremrangebylex(within range: (min: String, max: String), from key: String) -> EventLoopFuture<Int> {
        return send(command: "ZREMRANGEBYLEX", with: [key, range.min, range.max])
            .mapFromRESP()
    }

    /// Removes elements from a sorted set whose index is between the provided range.
    ///
    /// See [https://redis.io/commands/zremrangebyrank](https://redis.io/commands/zremrangebyrank)
    /// - Parameters:
    ///     - startingFrom: The starting index of the range.
    ///     - endingAt: The ending index of the range.
    ///     - from: The key of the sorted set to search.
    /// - Returns: The number of elements removed from the sorted set.
    @inlinable
    public func zremrangebyrank(startingFrom start: Int, endingAt stop: Int, from key: String) -> EventLoopFuture<Int> {
        return send(command: "ZREMRANGEBYRANK", with: [key, start, stop])
            .mapFromRESP()
    }

    /// Removes elements from a sorted set whose score is within the range specified.
    ///
    /// See [https://redis.io/commands/zremrangebyscore](https://redis.io/commands/zremrangebyscore)
    /// - Parameters:
    ///     - within: The score range to filter for elements to remove.
    ///     - from: The key of the sorted set to search.
    /// - Returns: The number of elements removed from the sorted set.
    @inlinable
    public func zremrangebyscore(within range: (min: String, max: String), from key: String) -> EventLoopFuture<Int> {
        return send(command: "ZREMRANGEBYSCORE", with: [key, range.min, range.max])
            .mapFromRESP()
    }
}
