import Foundation
import NIO

// MARK: General

extension RedisCommandExecutor {
    /// Gets all of the elements contained in a set.
    /// - Note: Ordering of results are stable between multiple calls of this method to the same set.
    ///
    /// Results are **UNSTABLE** in regards to the ordering of insertions through the `sadd` command and this method.
    ///
    /// See [https://redis.io/commands/smembers](https://redis.io/commands/smembers)
    /// - Parameter key: The key of the set.
    /// - Returns: A list of elements found within the set.
    @inlinable
    public func smembers(of key: String) -> EventLoopFuture<[RESPValue]> {
        return send(command: "SMEMBERS", with: [key])
            .mapFromRESP()
    }

    /// Checks if the element is included in a set.
    ///
    /// See [https://redis.io/commands/sismember](https://redis.io/commands/sismember)
    /// - Parameters:
    ///     - element: The element to look for in the set.
    ///     - key: The key of the set to look in.
    /// - Returns: `true` if the element is in the set.
    @inlinable
    public func sismember(_ element: RESPValueConvertible, of key: String) -> EventLoopFuture<Bool> {
        return send(command: "SISMEMBER", with: [key, element])
            .mapFromRESP(to: Int.self)
            .map { return $0 == 1 }
    }

    /// Gets the total count of elements within a set.
    ///
    /// See [https://redis.io/commands/scard](https://redis.io/commands/scard)
    /// - Parameter key: The key of the set.
    /// - Returns: The total count of elements in the set.
    @inlinable
    public func scard(of key: String) -> EventLoopFuture<Int> {
        return send(command: "SCARD", with: [key])
            .mapFromRESP()
    }

    /// Adds elements to a set.
    ///
    /// See [https://redis.io/commands/sadd](https://redis.io/commands/sadd)
    /// - Parameters:
    ///     - elements: The values to add to the set.
    ///     - key: The key of the set to insert into.
    /// - Returns: The number of elements that were added to the set.
    @inlinable
    public func sadd(_ elements: [RESPValueConvertible], to key: String) -> EventLoopFuture<Int> {
        guard elements.count > 0 else { return self.eventLoop.makeSucceededFuture(0) }

        return send(command: "SADD", with: [key] + elements)
            .mapFromRESP()
    }

    /// Removes elements from a set.
    ///
    /// See [https://redis.io/commands/srem](https://redis.io/commands/srem)
    /// - Parameters:
    ///     - elements: The values to remove from the set.
    ///     - key: The key of the set to remove from.
    /// - Returns: The number of elements that were removed from the set.
    @inlinable
    public func srem(_ elements: [RESPValueConvertible], from key: String) -> EventLoopFuture<Int> {
        guard elements.count > 0 else { return self.eventLoop.makeSucceededFuture(0) }

        return send(command: "SREM", with: [key] + elements)
            .mapFromRESP()
    }

    /// Randomly selects and removes one or more elements in a set.
    ///
    /// See [https://redis.io/commands/spop](https://redis.io/commands/spop)
    /// - Parameters:
    ///     - key: The key of the set.
    ///     - count: The max number of elements to pop from the set.
    /// - Returns: The element that was popped from the set.
    @inlinable
    public func spop(from key: String, max count: Int = 1) -> EventLoopFuture<[RESPValue]> {
        assert(count >= 0, "A negative max count is nonsense.")

        guard count > 0 else { return self.eventLoop.makeSucceededFuture([]) }

        return send(command: "SPOP", with: [key, count])
            .mapFromRESP()
    }

    /// Randomly selects one or more elements in a set.
    ///
    ///     connection.srandmember("my_key") // pulls just one random element
    ///     connection.srandmember("my_key", max: -3) // pulls up to 3 elements, allowing duplicates
    ///     connection.srandmember("my_key", max: 3) // pulls up to 3 elements, guaranteed unique
    ///
    /// See [https://redis.io/commands/srandmember](https://redis.io/commands/srandmember)
    /// - Parameters:
    ///     - key: The key of the set.
    ///     - count: The max number of elements to select from the set.
    /// - Returns: The elements randomly selected from the set.
    @inlinable
    public func srandmember(from key: String, max count: Int = 1) -> EventLoopFuture<[RESPValue]> {
        guard count != 0 else { return self.eventLoop.makeSucceededFuture([]) }

        return send(command: "SRANDMEMBER", with: [key, count])
            .mapFromRESP()
    }

    /// Moves an element from one set to another.
    ///
    /// See [https://redis.io/commands/smove](https://redis.io/commands/smove)
    /// - Parameters:
    ///     - element: The value to move from the source.
    ///     - sourceKey: The key of the source set.
    ///     - destKey: The key of the destination set.
    /// - Returns: `true` if the element was successfully removed from the source set.
    @inlinable
    public func smove(
        _ element: RESPValueConvertible,
        from sourceKey: String,
        to destKey: String
    ) -> EventLoopFuture<Bool> {
        guard sourceKey != destKey else { return self.eventLoop.makeSucceededFuture(true) }

        return send(command: "SMOVE", with: [sourceKey, destKey, element])
            .mapFromRESP()
            .map { return $0 == 1 }
    }

    /// Incrementally iterates over all values in a set.
    ///
    /// See [https://redis.io/commands/sscan](https://redis.io/commands/sscan)
    /// - Parameters:
    ///     - key: The key of the set.
    ///     - position: The position to start the scan from.
    ///     - count: The number of elements to advance by. Redis default is 10.
    ///     - match: A glob-style pattern to filter values to be selected from the result set.
    /// - Returns: A cursor position for additional invocations with a limited collection of elements found in the set.
    @inlinable
    public func sscan(
        _ key: String,
        startingFrom position: Int = 0,
        count: Int? = nil,
        matching match: String? = nil
    ) -> EventLoopFuture<(Int, [RESPValue])> {
        return _scan(command: "SSCAN", key, position, count, match)
    }
}

// MARK: Diff

extension RedisCommandExecutor {
    /// Calculates the difference between two or more sets.
    ///
    /// See [https://redis.io/commands/sdiff](https://redis.io/commands/sdiff)
    /// - Parameter keys: The source sets to calculate the difference of.
    /// - Returns: A list of elements resulting from the difference.
    @inlinable
    public func sdiff(of keys: [String]) -> EventLoopFuture<[RESPValue]> {
        guard keys.count > 0 else { return self.eventLoop.makeSucceededFuture([]) }

        return send(command: "SDIFF", with: keys)
            .mapFromRESP()
    }

    /// Calculates the difference between two or more sets and stores the result.
    /// - Important: If the destination key already exists, it is overwritten.
    ///
    /// See [https://redis.io/commands/sdiffstore](https://redis.io/commands/sdiffstore)
    /// - Parameters:
    ///     - destination: The key of the new set from the result.
    ///     - sources: The list of source sets to calculate the difference of.
    /// - Returns: The number of elements in the difference result.
    @inlinable
    public func sdiffstore(as destination: String, sources keys: [String]) -> EventLoopFuture<Int> {
        assert(keys.count > 0, "At least 1 key should be provided.")

        return send(command: "SDIFFSTORE", with: [destination] + keys)
            .mapFromRESP()
    }
}

// MARK: Intersect

extension RedisCommandExecutor {
    /// Calculates the intersection of two or more sets.
    ///
    /// See [https://redis.io/commands/sinter](https://redis.io/commands/sinter)
    /// - Parameter keys: The source sets to calculate the intersection of.
    /// - Returns: A list of elements resulting from the intersection.
    @inlinable
    public func sinter(of keys: [String]) -> EventLoopFuture<[RESPValue]> {
        guard keys.count > 0 else { return self.eventLoop.makeSucceededFuture([]) }

        return send(command: "SINTER", with: keys)
            .mapFromRESP()
    }

    /// Calculates the intersetion of two or more sets and stores the result.
    /// - Important: If the destination key already exists, it is overwritten.
    ///
    /// See [https://redis.io/commands/sinterstore](https://redis.io/commands/sinterstore)
    /// - Parameters:
    ///     - destination: The key of the new set from the result.
    ///     - sources: A list of source sets to calculate the intersection of.
    /// - Returns: The number of elements in the intersection result.
    @inlinable
    public func sinterstore(as destination: String, sources keys: [String]) -> EventLoopFuture<Int> {
        assert(keys.count > 0, "At least 1 key should be provided.")

        return send(command: "SINTERSTORE", with: [destination] + keys)
            .mapFromRESP()
    }
}

// MARK: Union

extension RedisCommandExecutor {
    /// Calculates the union of two or more sets.
    ///
    /// See [https://redis.io/commands/sunion](https://redis.io/commands/sunion)
    /// - Parameter keys: The source sets to calculate the union of.
    /// - Returns: A list of elements resulting from the union.
    @inlinable
    public func sunion(of keys: [String]) -> EventLoopFuture<[RESPValue]> {
        guard keys.count > 0 else { return self.eventLoop.makeSucceededFuture([]) }
        
        return send(command: "SUNION", with: keys)
            .mapFromRESP()
    }

    /// Calculates the union of two or more sets and stores the result.
    /// - Important: If the destination key already exists, it is overwritten.
    ///
    /// See [https://redis.io/commands/sunionstore](https://redis.io/commands/sunionstore)
    /// - Parameters:
    ///     - destination: The key of the new set from the result.
    ///     - sources: A list of source sets to calculate the union of.
    /// - Returns: The number of elements in the union result.
    @inlinable
    public func sunionstore(as destination: String, sources keys: [String]) -> EventLoopFuture<Int> {
        assert(keys.count > 0, "At least 1 key should be provided.")

        return send(command: "SUNIONSTORE", with: [destination] + keys)
            .mapFromRESP()
    }
}
