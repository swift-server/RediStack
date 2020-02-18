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

// MARK: General

extension NewRedisCommand {
    /// Gets the length of a list.
    ///
    /// See [https://redis.io/commands/llen](https://redis.io/commands/llen)
    /// - Parameter key: The key of the list.
    public static func llen(of key: RedisKey) -> NewRedisCommand<Int> {
        let args = [RESPValue(bulk: key)]
        return .init(keyword: "LLEN", arguments: args)
    }

    /// Gets the element from a list stored at the provided index position.
    ///
    /// See [https://redis.io/commands/lindex](https://redis.io/commands/lindex)
    /// - Parameters:
    ///     - index: The 0-based index of the element to get.
    ///     - key: The key of the list.
    public static func lindex(_ index: Int, from key: RedisKey) -> NewRedisCommand<RESPValue> {
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: index)
        ]
        return .init(keyword: "LINDEX", arguments: args)
    }

    /// Sets the value of an element in a list at the provided index position.
    ///
    /// See [https://redis.io/commands/lset](https://redis.io/commands/lset)
    /// - Parameters:
    ///     - index: The 0-based index of the element to set.
    ///     - value: The new value the element should be.
    ///     - key: The key of the list to update.
    @inlinable
    public static func lset<Value: RESPValueConvertible>(
        index: Int,
        to value: Value,
        in key: RedisKey
    ) -> NewRedisCommand<String> {
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: index),
            value.convertedToRESPValue()
        ]
        return .init(keyword: "LSET", arguments: args)
    }

    /// Removes elements from a list matching the value provided.
    ///
    /// See [https://redis.io/commands/lrem](https://redis.io/commands/lrem)
    /// - Parameters:
    ///     - value: The value to delete from the list.
    ///     - key: The key of the list to remove from.
    ///     - count: The max number of elements to remove matching the value. See Redis' documentation for more info.
    @inlinable
    public static func lrem<Value: RESPValueConvertible>(
        _ value: Value,
        from key: RedisKey,
        count: Int = 0
    ) -> NewRedisCommand<Int> {
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: count),
            value.convertedToRESPValue()
        ]
        return .init(keyword: "LREM", arguments: args)
    }
}

// MARK: LTrim

extension NewRedisCommand {
    /// Trims a List to only contain elements within the specified inclusive bounds of 0-based indices.
    ///
    /// See [https://redis.io/commands/ltrim](https://redis.io/commands/ltrim)
    /// - Parameters:
    ///     - key: The key of the List to trim.
    ///     - start: The index of the first element to keep.
    ///     - stop: The index of the last element to keep.
    public static func ltrim(_ key: RedisKey, before start: Int, after stop: Int) -> NewRedisCommand<String> {
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: start),
            .init(bulk: stop)
        ]
        return .init(keyword: "LTRIM", arguments: args)
    }
}

// MARK: LRange

extension NewRedisCommand {
    /// Gets all elements from a List within the the specified inclusive bounds of 0-based indices.
    ///
    /// See [https://redis.io/commands/lrange](https://redis.io/commands/lrange)
    /// - Parameters:
    ///     - key: The key of the List.
    ///     - firstIndex: The index of the first element to include in the range of elements returned.
    ///     - lastIndex: The index of the last element to include in the range of elements returned.
    public static func lrange(from key: RedisKey, firstIndex: Int, lastIndex: Int) -> NewRedisCommand<[RESPValue]> {
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: firstIndex),
            .init(bulk: lastIndex)
        ]
        return .init(keyword: "LRANGE", arguments: args)
    }
}

// MARK: Pop & Push

extension NewRedisCommand {
    /// Pops the last element from a source list and pushes it to a destination list.
    ///
    /// See [https://redis.io/commands/rpoplpush](https://redis.io/commands/rpoplpush)
    /// - Parameters:
    ///     - source: The key of the list to pop from.
    ///     - dest: The key of the list to push to.
    public static func rpoplpush(from source: RedisKey, to dest: RedisKey) -> NewRedisCommand<RESPValue> {
        let args: [RESPValue] = [
            .init(bulk: source),
            .init(bulk: dest)
        ]
        return .init(keyword: "RPOPLPUSH", arguments: args)
    }

    /// Pops the last element from a source list and pushes it to a destination list, blocking until
    /// an element is available from the source list.
    ///
    /// - Important:
    ///     This will block a connection from completing further commands until an element
    ///     is available to pop from the source list.
    ///
    ///     It is **highly** recommended to set a reasonable `timeout`
    ///     or to use the non-blocking `rpoplpush` method where possible.
    ///
    /// See [https://redis.io/commands/brpoplpush](https://redis.io/commands/brpoplpush)
    /// - Parameters:
    ///     - source: The key of the list to pop from.
    ///     - dest: The key of the list to push to.
    ///     - timeout: The max time to wait for a value to use. `0` seconds means to wait indefinitely.
    public static func brpoplpush(
        from source: RedisKey,
        to dest: RedisKey,
        timeout: TimeAmount = .seconds(0)
    ) -> NewRedisCommand<RESPValue?> {
        let args: [RESPValue] = [
            .init(bulk: source),
            .init(bulk: dest),
            .init(bulk: timeout.seconds)
        ]
        return .init(keyword: "BRPOPLPUSH", arguments: args)
    }
}

// MARK: Insert

extension NewRedisCommand {
    /// Inserts the element before the first element matching the "pivot" value specified.
    ///
    /// See [https://redis.io/commands/linsert](https://redis.io/commands/linsert)
    /// - Parameters:
    ///     - element: The value to insert into the list.
    ///     - key: The key of the list.
    ///     - pivot: The value of the element to insert before.
    @inlinable
    public static func linsert<Value: RESPValueConvertible>(
        _ element: Value,
        into key: RedisKey,
        before pivot: Value
    ) -> NewRedisCommand<Int> {
        return ._linsert(pivotKeyword: "BEFORE", element, key, pivot)
    }

    /// Inserts the element after the first element matching the "pivot" value provided.
    ///
    /// See [https://redis.io/commands/linsert](https://redis.io/commands/linsert)
    /// - Parameters:
    ///     - element: The value to insert into the list.
    ///     - key: The key of the list.
    ///     - pivot: The value of the element to insert after.
    @inlinable
    public static func linsert<Value: RESPValueConvertible>(
        _ element: Value,
        into key: RedisKey,
        after pivot: Value
    ) -> NewRedisCommand<Int> {
        return ._linsert(pivotKeyword: "AFTER", element, key, pivot)
    }

    @usableFromInline
    internal static func _linsert<Value: RESPValueConvertible>(
        pivotKeyword: String,
        _ element: Value,
        _ key: RedisKey,
        _ pivot: Value
    ) -> NewRedisCommand<Int> {
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: pivotKeyword),
            pivot.convertedToRESPValue(),
            element.convertedToRESPValue()
        ]
        return .init(keyword: "LINSERT", arguments: args)
    }
}

// MARK: Head Operations

extension NewRedisCommand {
    /// Removes the first element of a list.
    ///
    /// See [https://redis.io/commands/lpop](https://redis.io/commands/lpop)
    /// - Parameter key: The key of the list to pop from.
    public static func lpop(from key: RedisKey) -> NewRedisCommand<RESPValue> {
        let args = [RESPValue(bulk: key)]
        return .init(keyword: "LPOP", arguments: args)
    }

    /// Pushes all of the provided elements into a list.
    /// - Note: This inserts the elements at the head of the list; for the tail see `rpush(_:into:)`.
    ///
    /// See [https://redis.io/commands/lpush](https://redis.io/commands/lpush)
    /// - Parameters:
    ///     - elements: The values to push into the list.
    ///     - key: The key of the list.
    @inlinable
    public static func lpush<Value: RESPValueConvertible>(_ elements: [Value], into key: RedisKey) -> NewRedisCommand<Int> {
        assert(elements.count > 0, "At least 1 element should be provided.")
        
        var args: [RESPValue] = [.init(bulk: key)]
        args.append(convertingContentsOf: elements)
        
        return .init(keyword: "LPUSH", arguments: args)
    }

    /// Pushes an element into a list, but only if the key exists and holds a list.
    /// - Note: This inserts the element at the head of the list, for the tail see `rpushx(_:into:)`.
    ///
    /// See [https://redis.io/commands/lpushx](https://redis.io/commands/lpushx)
    /// - Parameters:
    ///     - element: The value to try and push into the list.
    ///     - key: The key of the list.
    @inlinable
    public static func lpushx<Value: RESPValueConvertible>(_ element: Value, into key: RedisKey) -> NewRedisCommand<Int> {
        let args: [RESPValue] = [
            .init(bulk: key),
            element.convertedToRESPValue()
        ]
        return .init(keyword: "LPUSHX", arguments: args)
    }
}

// MARK: Tail Operations

extension NewRedisCommand {
    /// Removes the last element a list.
    ///
    /// See [https://redis.io/commands/rpop](https://redis.io/commands/rpop)
    /// - Parameter key: The key of the list to pop from.
    public static func rpop(from key: RedisKey) -> NewRedisCommand<RESPValue> {
        let args = [RESPValue(bulk: key)]
        return .init(keyword: "RPOP", arguments: args)
    }

    /// Pushes all of the provided elements into a list.
    /// - Note: This inserts the elements at the tail of the list; for the head see `lpush(_:into:)`.
    ///
    /// See [https://redis.io/commands/rpush](https://redis.io/commands/rpush)
    ///     - elements: The values to push into the list.
    ///     - key: The key of the list.
    @inlinable
    public static func rpush<Value: RESPValueConvertible>(_ elements: [Value], into key: RedisKey) -> NewRedisCommand<Int> {
        assert(elements.count > 0, "At least 1 element should be provided.")

        var args: [RESPValue] = [.init(bulk: key)]
        args.append(convertingContentsOf: elements)
        
        return .init(keyword: "RPUSH", arguments: args)
    }

    /// Pushes an element into a list, but only if the key exists and holds a list.
    /// - Note: This inserts the element at the tail of the list; for the head see `lpushx(_:into:)`.
    ///
    /// See [https://redis.io/commands/rpushx](https://redis.io/commands/rpushx)
    /// - Parameters:
    ///     - element: The value to try and push into the list.
    ///     - key: The key of the list.
    @inlinable
    public static func rpushx<Value: RESPValueConvertible>(_ element: Value, into key: RedisKey) -> NewRedisCommand<Int> {
        let args: [RESPValue] = [
            .init(bulk: key),
            element.convertedToRESPValue()
        ]
        return .init(keyword: "RPUSHX", arguments: args)
    }
}

// MARK: Blocking Pop

extension NewRedisCommand {
    /// Removes the first element of a list, blocking until an element is available.
    ///
    /// - Important:
    ///     This will block a connection from completing further commands until an element
    ///     is available to pop from the list.
    ///
    ///     It is **highly** recommended to set a reasonable `timeout`
    ///     or to use the non-blocking `lpop` method where possible.
    ///
    /// See [https://redis.io/commands/blpop](https://redis.io/commands/blpop)
    /// - Parameters:
    ///     - key: The key of the list to pop from.
    ///     - timeout: The max time to wait for a value to use. `0`seconds means to wait indefinitely.
    public static func blpop(from keys: [RedisKey], timeout: TimeAmount = .seconds(0)) -> NewRedisCommand<[RESPValue]?> {
        var args = keys.map(RESPValue.init)
        args.append(.init(bulk: timeout.seconds))
        return .init(keyword: "BLPOP", arguments: args)
    }

    /// Removes the last element of a list, blocking until an element is available.
    ///
    /// - Important:
    ///     This will block a connection from completing further commands until an element
    ///     is available to pop from the group of lists.
    ///
    ///     It is **highly** recommended to set a reasonable `timeout`
    ///     or to use the non-blocking `rpop` method where possible.
    ///
    /// See [https://redis.io/commands/brpop](https://redis.io/commands/brpop)
    /// - Parameters:
    ///     - keys: The keys of lists in Redis that should be popped from.
    ///     - timeout: The max time to wait for a value to use. `0`seconds means to wait indefinitely.
    public static func brpop(from keys: [RedisKey], timeout: TimeAmount = .seconds(0)) -> NewRedisCommand<[RESPValue]?> {
        var args = keys.map(RESPValue.init)
        args.append(.init(bulk: timeout.seconds))
        return .init(keyword: "BRPOP", arguments: args)
    }
}
