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
            .flatMapThrowing {
                guard let result = $0.int else { throw RedisError.respConversion(to: Int.self) }
                return result == 1
            }
    }

    /// Returns the total count of elements in the set stored at key.
    ///
    /// [https://redis.io/commands/scard](https://redis.io/commands/scard)
    public func scard(_ key: String) -> EventLoopFuture<Int> {
        return send(command: "SCARD", with: [key])
            .flatMapThrowing {
                guard let count = $0.int else { throw RedisError.respConversion(to: Int.self) }
                return count
            }
    }

    /// Adds the provided items to the set stored at key, returning the count of items added.
    ///
    /// [https://redis.io/commands/sadd](https://redis.io/commands/sadd)
    /// - Parameter items: The elements to add to the set, stored as `bulkString`s.
    public func sadd(_ key: String, items: [RESPValueConvertible]) -> EventLoopFuture<Int> {
        assert(items.count > 0, "There must be at least 1 item to add.")

        return send(command: "SADD", with: [key] + items)
            .flatMapThrowing {
                guard let result = $0.int else { throw RedisError.respConversion(to: Int.self) }
                return result
            }
    }

    /// Removes the provided items from the set stored at key, returning the count of items removed.
    ///
    /// [https://redis.io/commands/srem](https://redis.io/commands/srem)
    /// - Parameter items: The elemnts to remove from the set, stored as `bulkString`s.
    public func srem(_ key: String, items: [RESPValueConvertible]) -> EventLoopFuture<Int> {
        assert(items.count > 0, "There must be at least 1 item listed to remove.")

        return send(command: "SREM", with: [key] + items)
            .flatMapThrowing {
                guard let result = $0.int else { throw RedisError.respConversion(to: Int.self) }
                return result
            }
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
            .flatMapThrowing {
                guard let elements = $0.array else { throw RedisError.respConversion(to: Array<RESPValue>.self) }
                return elements
            }
    }

    /// Functionally equivalent to `sdiff`, but instead stores the resulting set at the `destination` key
    /// and returns the count of elements in the result set.
    ///
    /// [https://redis.io/commands/sdiffstore](https://redis.io/commands/sdiffstore)
    /// - Important: If the `destination` key already exists, it is overwritten.
    public func sdiffstore(destination dest: String, _ keys: String...) -> EventLoopFuture<Int> {
        return send(command: "SDIFFSTORE", with: [dest] + keys)
            .flatMapThrowing {
                guard let count = $0.int else { throw RedisError.respConversion(to: Int.self) }
                return count
            }
    }

    /// Returns the members of the set resulting from the intersection of all the given sets.
    ///
    /// [https://redis.io/commands/sinter](https://redis.io/commands/sinter)
    public func sinter(_ keys: String...) -> EventLoopFuture<[RESPValue]> {
        return send(command: "SINTER", with: keys)
            .flatMapThrowing {
                guard let elements = $0.array else { throw RedisError.respConversion(to: Array<RESPValue>.self) }
                return elements
            }
    }

    /// Functionally equivalent to `sinter`, but instead stores the resulting set at the `destination` key
    /// and returns the count of elements in the result set.
    ///
    /// [https://redis.io/commands/sinterstore](https://redis.io/commands/sinterstore)
    /// - Important: If the `destination` key already exists, it is overwritten.
    public func sinterstore(destination dest: String, _ keys: String...) -> EventLoopFuture<Int> {
        return send(command: "SINTERSTORE", with: [dest] + keys)
            .flatMapThrowing {
                guard let count = $0.int else { throw RedisError.respConversion(to: Int.self) }
                return count
            }
    }

    /// Moves the `item` from the source key to the destination key.
    ///
    /// [https://redis.io/commands/smove](https://redis.io/commands/smove)
    /// - Important: This will resolve to `true` as long as it was successfully removed from the `source` key.
    public func smove(item: RESPValueConvertible, fromKey source: String, toKey dest: String) -> EventLoopFuture<Bool> {
        return send(command: "SMOVE", with: [source, dest, item])
            .flatMapThrowing {
                guard let result = $0.int else { throw RedisError.respConversion(to: Int.self) }
                return result == 1
            }
    }

    /// Returns the members of the set resulting from the union of all the given keys.
    ///
    /// [https://redis.io/commands/sunion](https://redis.io/commands/sunion)
    public func sunion(_ keys: String...) -> EventLoopFuture<[RESPValue]> {
        return send(command: "SUNION", with: keys)
            .flatMapThrowing {
                guard let elements = $0.array else { throw RedisError.respConversion(to: Array<RESPValue>.self) }
                return elements
            }
    }

    /// Functionally equivalent to `sunion`, but instead stores the resulting set at the `destination` key
    /// and returns the count of elements in the result set.
    ///
    /// [https://redis.io/commands/sunionstore](https://redis.io/commands/sunionstore)
    /// - Important: If the `destination` key already exists, it is overwritten.
    public func sunionstore(destination dest: String, _ keys: String...) -> EventLoopFuture<Int> {
        return send(command: "SUNIONSTORE", with: [dest] + keys)
            .flatMapThrowing {
                guard let count = $0.int else { throw RedisError.respConversion(to: Int.self) }
                return count
            }
    }

    /// Incrementally iterates over a set, returning a cursor position for additional calls with a limited collection
    /// of the entire set.
    ///
    /// [https://redis.io/commands/sscan](https://redis.io/commands/sscan)
    /// - Parameters:
    ///     - count: The number of elements to advance by. Redis default is 10.
    ///     - matching: A glob-style pattern to filter values to be selected from the result set.
    public func sscan(
        _ key: String,
        atPosition pos: Int = 0,
        count: Int? = nil,
        matching match: String? = nil
    ) -> EventLoopFuture<(Int, [RESPValue])> {
        var args: [RESPValueConvertible] = [key, pos]

        if let m = match {
            args.append("match")
            args.append(m)
        }
        if let c = count {
            args.append("count")
            args.append(c)
        }

        return send(command: "SSCAN", with: args)
            .flatMapThrowing {
                guard let response = $0.array else { throw RedisError.respConversion(to: Array<RESPValue>.self) }
                guard
                    let position = response[0].string,
                    let newPosition = Int(position)
                else { throw RedisError.respConversion(to: Int.self) }
                guard let elements = response[1].array else { throw RedisError.respConversion(to: Array<RESPValue>.self) }

                return (newPosition, elements)
            }
    }
}
