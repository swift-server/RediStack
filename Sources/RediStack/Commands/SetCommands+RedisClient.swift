///===----------------------------------------------------------------------===//
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

import NIO

// MARK: General

extension RedisClient {
    /// Gets all of the elements contained in a set.
    /// - Note: Ordering of results are stable between multiple calls of this method to the same set.
    ///
    /// Results are **UNSTABLE** in regards to the ordering of insertions through the `sadd` command and this method.
    ///
    /// See [https://redis.io/commands/smembers](https://redis.io/commands/smembers)
    /// - Parameter key: The key of the set.
    /// - Returns: A list of elements found within the set.
    public func smembers(of key: RedisKey) -> EventLoopFuture<[RESPValue]> {
        return self.sendCommand(.smembers(of: key))
    }

    /// Checks if the element is included in a set.
    ///
    /// See [https://redis.io/commands/sismember](https://redis.io/commands/sismember)
    /// - Parameters:
    ///     - element: The element to look for in the set.
    ///     - key: The key of the set to look in.
    /// - Returns: `true` if the element is in the set.
    @inlinable
    public func sismember<Value: RESPValueConvertible>(_ element: Value, of key: RedisKey) -> EventLoopFuture<Bool> {
        return self.sendCommand(.sismember(element, of: key))
            .map { return $0 == 1 }
    }

    /// Gets the total count of elements within a set.
    ///
    /// See [https://redis.io/commands/scard](https://redis.io/commands/scard)
    /// - Parameter key: The key of the set.
    /// - Returns: The total count of elements in the set.
    public func scard(of key: RedisKey) -> EventLoopFuture<Int> {
        return self.sendCommand(.scard(of: key))
    }

    /// Adds elements to a set.
    ///
    /// See [https://redis.io/commands/sadd](https://redis.io/commands/sadd)
    /// - Parameters:
    ///     - elements: The values to add to the set.
    ///     - key: The key of the set to insert into.
    /// - Returns: The number of elements that were added to the set.
    @inlinable
    public func sadd<Value: RESPValueConvertible>(_ elements: [Value], to key: RedisKey) -> EventLoopFuture<Int> {
        guard elements.count > 0 else { return self.eventLoop.makeSucceededFuture(0) }
        return self.sendCommand(.sadd(elements, to: key))
    }

    /// Adds elements to a set.
    ///
    /// See [https://redis.io/commands/sadd](https://redis.io/commands/sadd)
    /// - Parameters:
    ///     - elements: The values to add to the set.
    ///     - key: The key of the set to insert into.
    /// - Returns: The number of elements that were added to the set.
    @inlinable
    public func sadd<Value: RESPValueConvertible>(_ elements: Value..., to key: RedisKey) -> EventLoopFuture<Int> {
        return self.sadd(elements, to: key)
    }
    
    /// Adds an element to a set.
    ///
    /// See [https://redis.io/commands/sadd](https://redis.io/commands/sadd)
    /// - Parameters:
    ///     - elements: The value to add to the set.
    ///     - key: The key of the set to insert into.
    /// - Returns: `true` if the element was added to the set. Otherwise, `false`.
    @inlinable
    public func sadd<Value: RESPValueConvertible>(_ element: Value, to key: RedisKey) -> EventLoopFuture<Bool> {
        return self.sadd([element], to: key)
            .map { return $0 == 1 }
    }

    /// Removes elements from a set.
    ///
    /// See [https://redis.io/commands/srem](https://redis.io/commands/srem)
    /// - Parameters:
    ///     - elements: The values to remove from the set.
    ///     - key: The key of the set to remove from.
    /// - Returns: The number of elements that were removed from the set.
    @inlinable
    public func srem<Value: RESPValueConvertible>(_ elements: [Value], from key: RedisKey) -> EventLoopFuture<Int> {
        guard elements.count > 0 else { return self.eventLoop.makeSucceededFuture(0) }
        return self.sendCommand(.srem(elements, from: key))
    }

    /// Removes elements from a set.
    ///
    /// See [https://redis.io/commands/srem](https://redis.io/commands/srem)
    /// - Parameters:
    ///     - elements: The values to remove from the set.
    ///     - key: The key of the set to remove from.
    /// - Returns: The number of elements that were removed from the set.
    @inlinable
    public func srem<Value: RESPValueConvertible>(_ elements: Value..., from key: RedisKey) -> EventLoopFuture<Int> {
        return self.srem(elements, from: key)
    }

    /// Removes elements from a set.
    ///
    /// See [https://redis.io/commands/srem](https://redis.io/commands/srem)
    /// - Parameters:
    ///     - elements: The values to remove from the set.
    ///     - key: The key of the set to remove from.
    /// - Returns: The number of elements that were removed from the set.
    @inlinable
    public func srem<Value: RESPValueConvertible>(_ element: Value, from key: RedisKey) -> EventLoopFuture<Bool> {
        return self.srem([element], from: key)
            .map { return $0 == 1 }
    }
    
    /// Randomly selects and removes one or more elements in a set.
    ///
    /// See [https://redis.io/commands/spop](https://redis.io/commands/spop)
    /// - Parameters:
    ///     - key: The key of the set.
    ///     - count: The max number of elements to pop from the set.
    /// - Returns: The element that was popped from the set.
    public func spop(from key: RedisKey, max count: Int = 1) -> EventLoopFuture<[RESPValue]> {
        guard count > 0 else { return self.eventLoop.makeSucceededFuture([]) }
        return self.sendCommand(.spop(from: key, max: count))
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
    public func srandmember(from key: RedisKey, max count: Int = 1) -> EventLoopFuture<[RESPValue]> {
        guard count != 0 else { return self.eventLoop.makeSucceededFuture([]) }
        return self.sendCommand(.srandmember(from: key, max: count))
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
    public func smove<Value: RESPValueConvertible>(
        _ element: Value,
        from sourceKey: RedisKey,
        to destKey: RedisKey
    ) -> EventLoopFuture<Bool> {
        guard sourceKey != destKey else { return self.eventLoop.makeSucceededFuture(true) }
        return self.sendCommand(.smove(element, from: sourceKey, to: destKey))
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
    public func sscan(
        _ key: RedisKey,
        startingFrom position: UInt = 0,
        count: Int? = nil,
        matching match: String? = nil
    ) -> EventLoopFuture<(UInt, [RESPValue])> {
        return self._sendScanCommand(.sscan(key, startingFrom: position, count: count, matching: match))
    }
}
    
// MARK: Diff

extension RedisClient {
    /// Calculates the difference between two or more sets.
    ///
    /// See [https://redis.io/commands/sdiff](https://redis.io/commands/sdiff)
    /// - Parameter keys: The source sets to calculate the difference of.
    /// - Returns: A list of elements resulting from the difference.
    public func sdiff(of keys: [RedisKey]) -> EventLoopFuture<[RESPValue]> {
        guard keys.count > 0 else { return self.eventLoop.makeSucceededFuture([]) }
        return self.sendCommand(.sdiff(of: keys))
    }

    /// Calculates the difference between two or more sets.
    ///
    /// See [https://redis.io/commands/sdiff](https://redis.io/commands/sdiff)
    /// - Parameter keys: The source sets to calculate the difference of.
    /// - Returns: A list of elements resulting from the difference.
    public func sdiff(of keys: RedisKey...) -> EventLoopFuture<[RESPValue]> {
        return self.sdiff(of: keys)
    }

    /// Calculates the difference between two or more sets and stores the result.
    /// - Important: If the destination key already exists, it is overwritten.
    ///
    /// See [https://redis.io/commands/sdiffstore](https://redis.io/commands/sdiffstore)
    /// - Parameters:
    ///     - destination: The key of the new set from the result.
    ///     - sources: The list of source sets to calculate the difference of.
    /// - Returns: The number of elements in the difference result.
    public func sdiffstore(as destination: RedisKey, sources keys: [RedisKey]) -> EventLoopFuture<Int> {
        return self.sendCommand(.sdiffstore(as: destination, sources: keys))
    }
}
    
// MARK: Intersect

extension RedisClient {
    /// Calculates the intersection of two or more sets.
    ///
    /// See [https://redis.io/commands/sinter](https://redis.io/commands/sinter)
    /// - Parameter keys: The source sets to calculate the intersection of.
    /// - Returns: A list of elements resulting from the intersection.
    public func sinter(of keys: [RedisKey]) -> EventLoopFuture<[RESPValue]> {
        guard keys.count > 0 else { return self.eventLoop.makeSucceededFuture([]) }
        return self.sendCommand(.sinter(of: keys))
    }

    /// Calculates the intersection of two or more sets.
    ///
    /// See [https://redis.io/commands/sinter](https://redis.io/commands/sinter)
    /// - Parameter keys: The source sets to calculate the intersection of.
    /// - Returns: A list of elements resulting from the intersection.
    public func sinter(of keys: RedisKey...) -> EventLoopFuture<[RESPValue]> {
        return self.sinter(of: keys)
    }

    /// Calculates the intersetion of two or more sets and stores the result.
    /// - Important: If the destination key already exists, it is overwritten.
    ///
    /// See [https://redis.io/commands/sinterstore](https://redis.io/commands/sinterstore)
    /// - Parameters:
    ///     - destination: The key of the new set from the result.
    ///     - sources: A list of source sets to calculate the intersection of.
    /// - Returns: The number of elements in the intersection result.
    public func sinterstore(as destination: RedisKey, sources keys: [RedisKey]) -> EventLoopFuture<Int> {
        return self.sendCommand(.sinterstore(as: destination, sources: keys))
    }
}
    
// MARK: Union

extension RedisClient {
    /// Calculates the union of two or more sets.
    ///
    /// See [https://redis.io/commands/sunion](https://redis.io/commands/sunion)
    /// - Parameter keys: The source sets to calculate the union of.
    /// - Returns: A list of elements resulting from the union.
    public func sunion(of keys: [RedisKey]) -> EventLoopFuture<[RESPValue]> {
        guard keys.count > 0 else { return self.eventLoop.makeSucceededFuture([]) }
        return self.sendCommand(.sunion(of: keys))
    }

    /// Calculates the union of two or more sets.
    ///
    /// See [https://redis.io/commands/sunion](https://redis.io/commands/sunion)
    /// - Parameter keys: The source sets to calculate the union of.
    /// - Returns: A list of elements resulting from the union.
    public func sunion(of keys: RedisKey...) -> EventLoopFuture<[RESPValue]> {
        return self.sunion(of: keys)
    }

    /// Calculates the union of two or more sets and stores the result.
    /// - Important: If the destination key already exists, it is overwritten.
    ///
    /// See [https://redis.io/commands/sunionstore](https://redis.io/commands/sunionstore)
    /// - Parameters:
    ///     - destination: The key of the new set from the result.
    ///     - sources: A list of source sets to calculate the union of.
    /// - Returns: The number of elements in the union result.
    public func sunionstore(as destination: RedisKey, sources keys: [RedisKey]) -> EventLoopFuture<Int> {
        return self.sendCommand(.sunionstore(as: destination, sources: keys))
    }
}
