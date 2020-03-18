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
        let args = [RESPValue(bulk: key)]
        return send(command: "SMEMBERS", with: args)
            .map()
    }
    
    /// Gets all of the elements contained in a set.
    /// - Note: Ordering of results are stable between multiple calls of this method to the same set.
    ///
    /// Results are **UNSTABLE** in regards to the ordering of insertions through the `sadd` command and this method.
    ///
    /// See [https://redis.io/commands/smembers](https://redis.io/commands/smembers)
    /// - Parameters:
    ///     - key: The key of the set.
    ///     - type: The type to convert the values to.
    /// - Returns: A list of elements found within the set. Elements that fail the `RESPValue` conversion will be `nil`.
    @inlinable
    public func smembers<Value: RESPValueConvertible>(of key: RedisKey, as type: Value.Type) -> EventLoopFuture<[Value?]> {
        return self.smembers(of: key)
            .map { return $0.map(Value.init(fromRESP:)) }
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
        let args: [RESPValue] = [
            .init(bulk: key),
            element.convertedToRESPValue()
        ]
        return send(command: "SISMEMBER", with: args)
            .map(to: Int.self)
            .map { return $0 == 1 }
    }

    /// Gets the total count of elements within a set.
    ///
    /// See [https://redis.io/commands/scard](https://redis.io/commands/scard)
    /// - Parameter key: The key of the set.
    /// - Returns: The total count of elements in the set.
    public func scard(of key: RedisKey) -> EventLoopFuture<Int> {
        let args = [RESPValue(bulk: key)]
        return send(command: "SCARD", with: args)
            .map()
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
        
        var args: [RESPValue] = [.init(bulk: key)]
        args.append(convertingContentsOf: elements)

        return send(command: "SADD", with: args)
            .map()
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

        var args: [RESPValue] = [.init(bulk: key)]
        args.append(convertingContentsOf: elements)
        
        return send(command: "SREM", with: args)
            .map()
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

    /// Randomly selects and removes one or more elements in a set.
    ///
    /// See [https://redis.io/commands/spop](https://redis.io/commands/spop)
    /// - Parameters:
    ///     - key: The key of the set.
    ///     - count: The max number of elements to pop from the set.
    /// - Returns: The element that was popped from the set.
    public func spop(from key: RedisKey, max count: Int = 1) -> EventLoopFuture<[RESPValue]> {
        assert(count >= 0, "A negative max count is nonsense.")

        guard count > 0 else { return self.eventLoop.makeSucceededFuture([]) }
        
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: count)
        ]
        return send(command: "SPOP", with: args)
            .map()
    }

    /// Randomly selects and removes one or more elements in a set.
    ///
    /// See [https://redis.io/commands/spop](https://redis.io/commands/spop)
    /// - Parameters:
    ///     - key: The key of the set.
    ///     - type: The type to convert the values to.
    ///     - count: The max number of elements to pop from the set.
    /// - Returns: The element that was popped from the set. Elements that fail the `RESPValue` conversion will be `nil`.
    @inlinable
    public func spop<Value: RESPValueConvertible>(
        from key: RedisKey,
        as type: Value.Type,
        max count: Int = 1
    ) -> EventLoopFuture<[Value?]> {
        return self.spop(from: key, max: count)
            .map { return $0.map(Value.init(fromRESP:)) }
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

        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: count)
        ]
        return send(command: "SRANDMEMBER", with: args)
            .map()
    }
    
    /// Randomly selects one or more elements in a set.
    ///
    /// See [https://redis.io/commands/srandmember](https://redis.io/commands/srandmember)
    /// - Parameters:
    ///     - key: The key of the set.
    ///     - type; The type to convert the values to.
    ///     - count: The max number of elements to select from the set.
    /// - Returns: The elements randomly selected from the set. Elements that fail the `RESPValue` conversion will be `nil`.
    @inlinable
    public func srandmember<Value: RESPValueConvertible>(
        from key: RedisKey,
        as type: Value.Type,
        max count: Int = 1
    ) -> EventLoopFuture<[Value?]> {
        return self.srandmember(from: key, max: count)
            .map { return $0.map(Value.init(fromRESP:)) }
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

        let args: [RESPValue] = [
            .init(bulk: sourceKey),
            .init(bulk: destKey),
            element.convertedToRESPValue()
        ]
        return send(command: "SMOVE", with: args)
            .map()
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
        startingFrom position: Int = 0,
        matching match: String? = nil,
        count: Int? = nil
    ) -> EventLoopFuture<(Int, [RESPValue])> {
        return _scan(command: "SSCAN", key, position, match, count)
    }
    
    /// Incrementally iterates over all values in a set.
    ///
    /// See [https://redis.io/commands/sscan](https://redis.io/commands/sscan)
    /// - Parameters:
    ///     - key: The key of the set.
    ///     - position: The position to start the scan from.
    ///     - match: A glob-style pattern to filter values to be selected from the result set.
    ///     - count: The number of elements to advance by. Redis default is 10.
    ///     - valueType: The type to convert the value to.
    /// - Returns: A cursor position for additional invocations with a limited collection of elements found in the set. Elements that fail the `RESPValue` conversion will be `nil`.
    @inlinable
    public func sscan<Value: RESPValueConvertible>(
        _ key: RedisKey,
        startingFrom position: Int = 0,
        matching match: String? = nil,
        count: Int? = nil,
        valueType: Value.Type
    ) -> EventLoopFuture<(Int, [Value?])> {
        return self.sscan(key, startingFrom: position, matching: match, count: count)
            .map { (cursor, rawValues) in
                let values = rawValues.map(Value.init(fromRESP:))
                return (cursor, values)
            }
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

        let args = keys.map(RESPValue.init)
        return send(command: "SDIFF", with: args)
            .map()
    }
    
    /// Calculates the difference between two or more sets.
    ///
    /// See [https://redis.io/commands/sdiff](https://redis.io/commands/sdiff)
    /// - Parameters:
    ///     - keys: The source sets to calculate the difference of.
    ///     - valueType: The type to convert the values to.
    /// - Returns: A list of elements resulting from the difference. Elements that fail the `RESPValue` conversion will be `nil`.
    @inlinable
    public func sdiff<Value: RESPValueConvertible>(of keys: [RedisKey], valueType: Value.Type) -> EventLoopFuture<[Value?]> {
        return self.sdiff(of: keys)
            .map { return $0.map(Value.init(fromRESP:)) }
    }
    
    /// Calculates the difference between two or more sets.
    ///
    /// See [https://redis.io/commands/sdiff](https://redis.io/commands/sdiff)
    /// - Parameter keys: The source sets to calculate the difference of.
    /// - Returns: A list of elements resulting from the difference.
    public func sdiff(of keys: RedisKey...) -> EventLoopFuture<[RESPValue]> {
        return self.sdiff(of: keys)
    }
    
    /// Calculates the difference between two or more sets.
    ///
    /// See [https://redis.io/commands/sdiff](https://redis.io/commands/sdiff)
    /// - Parameters:
    ///     - keys: The source sets to calculate the difference of.
    ///     - valueType: The type to convert the values to.
    /// - Returns: A list of elements resulting from the difference. Elements that fail the `RESPValue` conversion will be `nil`.
    @inlinable
    public func sdiff<Value: RESPValueConvertible>(of keys: RedisKey..., valueType: Value.Type) -> EventLoopFuture<[Value?]> {
        return self.sdiff(of: keys, valueType: valueType)
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
        assert(keys.count > 0, "At least 1 key should be provided.")

        var args: [RESPValue] = [.init(bulk: destination)]
        args.append(convertingContentsOf: keys)
        
        return send(command: "SDIFFSTORE", with: args)
            .map()
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

        let args = keys.map(RESPValue.init)
        return send(command: "SINTER", with: args)
            .map()
    }
    
    /// Calculates the intersection of two or more sets.
    ///
    /// See [https://redis.io/commands/sinter](https://redis.io/commands/sinter)
    /// - Parameters:
    ///     - keys: The source sets to calculate the intersection of.
    ///     - valueType: The type to convert all values to.
    /// - Returns: A list of elements resulting from the intersection. Elements that fail the `RESPValue` conversion will be `nil`.
    @inlinable
    public func sinter<Value: RESPValueConvertible>(of keys: [RedisKey], valueType: Value.Type) -> EventLoopFuture<[Value?]> {
        return self.sinter(of: keys)
            .map { return $0.map(Value.init(fromRESP:)) }
    }
    
    /// Calculates the intersection of two or more sets.
    ///
    /// See [https://redis.io/commands/sinter](https://redis.io/commands/sinter)
    /// - Parameter keys: The source sets to calculate the intersection of.
    /// - Returns: A list of elements resulting from the intersection.
    public func sinter(of keys: RedisKey...) -> EventLoopFuture<[RESPValue]> {
        return self.sinter(of: keys)
    }
    
    /// Calculates the intersection of two or more sets.
    ///
    /// See [https://redis.io/commands/sinter](https://redis.io/commands/sinter)
    /// - Parameters:
    ///     - keys: The source sets to calculate the intersection of.
    ///     - valueType: The type to convert all values to.
    /// - Returns: A list of elements resulting from the intersection. Elements that fail the `RESPValue` conversion will be `nil`.
    @inlinable
    public func sinter<Value: RESPValueConvertible>(of keys: RedisKey..., valueType: Value.Type) -> EventLoopFuture<[Value?]> {
        return self.sinter(of: keys, valueType: valueType)
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
        assert(keys.count > 0, "At least 1 key should be provided.")

        var args: [RESPValue] = [.init(bulk: destination)]
        args.append(convertingContentsOf: keys)
        
        return send(command: "SINTERSTORE", with: args)
            .map()
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
        
        let args = keys.map(RESPValue.init)
        return send(command: "SUNION", with: args)
            .map()
    }
    
    /// Calculates the union of two or more sets.
    ///
    /// See [https://redis.io/commands/sunion](https://redis.io/commands/sunion)
    /// - Parameters:
    ///     - keys: The source sets to calculate the union of.
    ///     - valueType: The type to convert all values to.
    /// - Returns: A list of elements resulting from the union. Elements that fail the `RESPValue` conversion will be `nil`.
    @inlinable
    public func sunion<Value: RESPValueConvertible>(of keys: [RedisKey], valueType: Value.Type) -> EventLoopFuture<[Value?]> {
        return self.sunion(of: keys)
            .map { return $0.map(Value.init(fromRESP:)) }
    }
    
    /// Calculates the union of two or more sets.
    ///
    /// See [https://redis.io/commands/sunion](https://redis.io/commands/sunion)
    /// - Parameter keys: The source sets to calculate the union of.
    /// - Returns: A list of elements resulting from the union.
    public func sunion(of keys: RedisKey...) -> EventLoopFuture<[RESPValue]> {
        return self.sunion(of: keys)
    }
    
    /// Calculates the union of two or more sets.
    ///
    /// See [https://redis.io/commands/sunion](https://redis.io/commands/sunion)
    /// - Parameters:
    ///     - keys: The source sets to calculate the union of.
    ///     - valueType: The type to convert all values to.
    /// - Returns: A list of elements resulting from the union. Elements that fail the `RESPValue` conversion will be `nil`.
    @inlinable
    public func sunion<Value: RESPValueConvertible>(of keys: RedisKey..., valueType: Value.Type) -> EventLoopFuture<[Value?]> {
        return self.sunion(of: keys, valueType: valueType)
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
        assert(keys.count > 0, "At least 1 key should be provided.")

        var args: [RESPValue] = [.init(bulk: destination)]
        args.append(convertingContentsOf: keys)
        
        return send(command: "SUNIONSTORE", with: args)
            .map()
    }
}
