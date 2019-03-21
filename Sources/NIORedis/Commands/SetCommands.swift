import Foundation
import NIO

extension RedisCommandExecutor {
    /// Returns the all of the elements of the set stored at key.
    ///
    /// Ordering of results are stable between multiple calls of this method to the same set.
    ///
    /// Results are **UNSTABLE** in regards to the ordering of insertions through the `sadd` command and this method.
    ///
    /// [https://redis.io/commands/smembers](https://redis.io/commands/smembers)
    public func smembers(_ key: String) -> EventLoopFuture<RESPValue> {
        return send(command: "SMEMBERS", with: [key])
    }

    /// Checks if the provided item is included in the set stored at key.
    ///
    /// https://redis.io/commands/sismember
    /// - Parameter item: The element to look in the set for, stored as a `bulkString`.
    public func sismember(_ key: String, item: RESPValueConvertible) -> EventLoopFuture<Bool> {
        return send(command: "SISMEMBER", with: [key, item])
            .mapFromRESP(to: Int.self)
            .map { return $0 == 1 }
    }

    /// Returns the total count of elements in the set stored at key.
    ///
    /// [https://redis.io/commands/scard](https://redis.io/commands/scard)
    public func scard(_ key: String) -> EventLoopFuture<Int> {
        return send(command: "SCARD", with: [key])
            .mapFromRESP()
    }

    /// Adds the provided items to the set stored at key, returning the count of items added.
    ///
    /// [https://redis.io/commands/sadd](https://redis.io/commands/sadd)
    /// - Parameter items: The elements to add to the set, stored as `bulkString`s.
    public func sadd(_ key: String, items: [RESPValueConvertible]) -> EventLoopFuture<Int> {
        assert(items.count > 0, "There must be at least 1 item to add.")

        return send(command: "SADD", with: [key] + items)
            .mapFromRESP()
    }

    /// Removes the provided items from the set stored at key, returning the count of items removed.
    ///
    /// [https://redis.io/commands/srem](https://redis.io/commands/srem)
    /// - Parameter items: The elemnts to remove from the set, stored as `bulkString`s.
    public func srem(_ key: String, items: [RESPValueConvertible]) -> EventLoopFuture<Int> {
        assert(items.count > 0, "There must be at least 1 item listed to remove.")

        return send(command: "SREM", with: [key] + items)
            .mapFromRESP()
    }

    /// Randomly selects an item from the set stored at key, and removes it.
    ///
    /// [https://redis.io/commands/spop](https://redis.io/commands/spop)
    public func spop(_ key: String) -> EventLoopFuture<RESPValue> {
        return send(command: "SPOP", with: [key])
    }

    /// Randomly selects elements from the set stored at string, up to the `count` provided.
    /// Use the `RESPValue.array` property to access the underlying values.
    ///
    ///     connection.srandmember("my_key") // pulls just one random element
    ///     connection.srandmember("my_key", max: -3) // pulls up to 3 elements, allowing duplicates
    ///     connection.srandmember("my_key", max: 3) // pulls up to 3 elements, guaranteed unique
    ///
    /// [https://redis.io/commands/srandmember](https://redis.io/commands/srandmember)
    public func srandmember(_ key: String, max count: Int = 1) -> EventLoopFuture<RESPValue> {
        assert(count != 0, "A count of zero is a noop for selecting a random element.")

        return send(command: "SRANDMEMBER", with: [key, count.description])
    }

    /// Returns the members of the set resulting from the difference between the first set and all the successive sets.
    ///
    /// [https://redis.io/commands/sdiff](https://redis.io/commands/sdiff)
    public func sdiff(_ keys: String...) -> EventLoopFuture<[RESPValue]> {
        return send(command: "SDIFF", with: keys)
            .mapFromRESP()
    }

    /// Functionally equivalent to `sdiff`, but instead stores the resulting set at the `destination` key
    /// and returns the count of elements in the result set.
    ///
    /// [https://redis.io/commands/sdiffstore](https://redis.io/commands/sdiffstore)
    /// - Important: If the `destination` key already exists, it is overwritten.
    public func sdiffstore(destination dest: String, _ keys: String...) -> EventLoopFuture<Int> {
        return send(command: "SDIFFSTORE", with: [dest] + keys)
            .mapFromRESP()
    }

    /// Returns the members of the set resulting from the intersection of all the given sets.
    ///
    /// [https://redis.io/commands/sinter](https://redis.io/commands/sinter)
    public func sinter(_ keys: String...) -> EventLoopFuture<[RESPValue]> {
        return send(command: "SINTER", with: keys)
            .mapFromRESP()
    }

    /// Functionally equivalent to `sinter`, but instead stores the resulting set at the `destination` key
    /// and returns the count of elements in the result set.
    ///
    /// [https://redis.io/commands/sinterstore](https://redis.io/commands/sinterstore)
    /// - Important: If the `destination` key already exists, it is overwritten.
    public func sinterstore(destination dest: String, _ keys: String...) -> EventLoopFuture<Int> {
        return send(command: "SINTERSTORE", with: [dest] + keys)
            .mapFromRESP()
    }

    /// Moves the `item` from the source key to the destination key.
    ///
    /// [https://redis.io/commands/smove](https://redis.io/commands/smove)
    /// - Important: This will resolve to `true` as long as it was successfully removed from the `source` key.
    public func smove(item: RESPValueConvertible, fromKey source: String, toKey dest: String) -> EventLoopFuture<Bool> {
        return send(command: "SMOVE", with: [source, dest, item])
            .mapFromRESP()
            .map { return $0 == 1 }
    }

    /// Returns the members of the set resulting from the union of all the given keys.
    ///
    /// [https://redis.io/commands/sunion](https://redis.io/commands/sunion)
    public func sunion(_ keys: String...) -> EventLoopFuture<[RESPValue]> {
        return send(command: "SUNION", with: keys)
            .mapFromRESP()
    }

    /// Functionally equivalent to `sunion`, but instead stores the resulting set at the `destination` key
    /// and returns the count of elements in the result set.
    ///
    /// [https://redis.io/commands/sunionstore](https://redis.io/commands/sunionstore)
    /// - Important: If the `destination` key already exists, it is overwritten.
    public func sunionstore(destination dest: String, _ keys: String...) -> EventLoopFuture<Int> {
        return send(command: "SUNIONSTORE", with: [dest] + keys)
            .mapFromRESP()
    }

    /// Incrementally iterates over all values in a set.
    ///
    /// [https://redis.io/commands/sscan](https://redis.io/commands/sscan)
    /// - Parameters:
    ///     - count: The number of elements to advance by. Redis default is 10.
    ///     - matching: A glob-style pattern to filter values to be selected from the result set.
    /// - Returns: A cursor position for additional invocations with a limited collection of values stored at the keys.
    public func sscan(
        _ key: String,
        atPosition pos: Int = 0,
        count: Int? = nil,
        matching match: String? = nil) -> EventLoopFuture<(Int, [RESPValue])>
    {
        return _scan(command: "SSCAN", resultType: [RESPValue].self, key, pos, count, match)
    }
}
