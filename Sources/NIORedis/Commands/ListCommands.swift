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

// MARK: General

extension RedisClient {
    /// Gets the length of a list.
    ///
    /// See [https://redis.io/commands/llen](https://redis.io/commands/llen)
    /// - Parameter key: The key of the list.
    /// - Returns: The number of elements in the list.
    @inlinable
    public func llen(of key: String) -> EventLoopFuture<Int> {
        return send(command: "LLEN", with: [key])
            .mapFromRESP()
    }

    /// Gets the element from a list stored at the provided index position.
    ///
    /// See [https://redis.io/commands/lindex](https://redis.io/commands/lindex)
    /// - Parameters:
    ///     - index: The 0-based index of the element to get.
    ///     - key: The key of the list.
    /// - Returns: The element stored at index, or `.null` if out of bounds.
    @inlinable
    public func lindex(_ index: Int, from key: String) -> EventLoopFuture<RESPValue> {
        return send(command: "LINDEX", with: [key, index])
    }

    /// Sets the value of an element in a list at the provided index position.
    ///
    /// See [https://redis.io/commands/lset](https://redis.io/commands/lset)
    /// - Parameters:
    ///     - index: The 0-based index of the element to set.
    ///     - value: The new value the element should be.
    ///     - key: The key of the list to update.
    /// - Returns: An `EventLoopFuture` that resolves when the operation has succeeded, or fails with a `RedisError`.
    @inlinable
    public func lset(
        index: Int,
        to value: RESPValueConvertible,
        in key: String
    ) -> EventLoopFuture<Void> {
        return send(command: "LSET", with: [key, index, value])
            .map { _ in () }
    }

    /// Removes elements from a list matching the value provided.
    ///
    /// See [https://redis.io/commands/lrem](https://redis.io/commands/lrem)
    /// - Parameters:
    ///     - value: The value to delete from the list.
    ///     - key: The key of the list to remove from.
    ///     - count: The max number of elements to remove matching the value. See Redis' documentation for more info.
    /// - Returns: The number of elements removed from the list.
    @inlinable
    public func lrem(
        _ value: RESPValueConvertible,
        from key: String,
        count: Int = 0
    ) -> EventLoopFuture<Int> {
        return send(command: "LREM", with: [key, count, value])
            .mapFromRESP()
    }

    /// Trims a list to only contain elements within the specified inclusive bounds of 0-based indices.
    ///
    /// See [https://redis.io/commands/ltrim](https://redis.io/commands/ltrim)
    /// - Parameters:
    ///     - key: The key of the list to trim.
    ///     - start: The index of the first element to keep.
    ///     - stop: The index of the last element to keep.
    /// - Returns: An `EventLoopFuture` that resolves when the operation has succeeded, or fails with a `RedisError`.
    @inlinable
    public func ltrim(_ key: String, before start: Int, after stop: Int) -> EventLoopFuture<Void> {
        return send(command: "LTRIM", with: [key, start, stop])
            .map { _ in () }
    }

    /// Gets all elements from a list within the the specified inclusive bounds of 0-based indices.
    ///
    /// See [https://redis.io/commands/lrange](https://redis.io/commands/lrange)
    /// - Parameters:
    ///     - range: The range of inclusive indices of elements to get.
    ///     - key: The key of the list.
    /// - Returns: A list of elements found within the range specified.
    @inlinable
    public func lrange(
        within range: (startIndex: Int, endIndex: Int),
        from key: String
    ) -> EventLoopFuture<[RESPValue]> {
        return send(command: "LRANGE", with: [key, range.startIndex, range.endIndex])
            .mapFromRESP()
    }

    /// Pops the last element from a source list and pushes it to a destination list.
    ///
    /// See [https://redis.io/commands/rpoplpush](https://redis.io/commands/rpoplpush)
    /// - Parameters:
    ///     - source: The key of the list to pop from.
    ///     - dest: The key of the list to push to.
    /// - Returns: The element that was moved.
    @inlinable
    public func rpoplpush(from source: String, to dest: String) -> EventLoopFuture<RESPValue> {
        return send(command: "RPOPLPUSH", with: [source, dest])
    }
}

// MARK: Insert

extension RedisClient {
    /// Inserts the element before the first element matching the "pivot" value specified.
    ///
    /// See [https://redis.io/commands/linsert](https://redis.io/commands/linsert)
    /// - Parameters:
    ///     - element: The value to insert into the list.
    ///     - key: The key of the list.
    ///     - pivot: The value of the element to insert before.
    /// - Returns: The size of the list after the insert, or -1 if an element matching the pivot value was not found.
    @inlinable
    public func linsert<T>(_ element: T, into key: String, before pivot: T) -> EventLoopFuture<Int>
        where T: RESPValueConvertible
    {
        return _linsert(pivotKeyword: "BEFORE", element, key, pivot)
    }

    /// Inserts the element after the first element matching the "pivot" value provided.
    ///
    /// See [https://redis.io/commands/linsert](https://redis.io/commands/linsert)
    /// - Parameters:
    ///     - element: The value to insert into the list.
    ///     - key: The key of the list.
    ///     - pivot: The value of the element to insert after.
    /// - Returns: The size of the list after the insert, or -1 if an element matching the pivot value was not found.
    @inlinable
    public func linsert<T>(_ element: T, into key: String, after pivot: T) -> EventLoopFuture<Int>
        where T: RESPValueConvertible
    {
        return _linsert(pivotKeyword: "AFTER", element, key, pivot)
    }

    @usableFromInline
    func _linsert(
        pivotKeyword: String,
        _ element: RESPValueConvertible,
        _ key: String,
        _ pivot: RESPValueConvertible
    ) -> EventLoopFuture<Int> {
        return send(command: "LINSERT", with: [key, pivotKeyword, pivot, element])
            .mapFromRESP()
    }
}

// MARK: Head Operations

extension RedisClient {
    /// Removes the first element of a list.
    ///
    /// See [https://redis.io/commands/lpop](https://redis.io/commands/lpop)
    /// - Parameter key: The key of the list to pop from.
    /// - Returns: The element that was popped from the list, or `.null`.
    @inlinable
    public func lpop(from key: String) -> EventLoopFuture<RESPValue> {
        return send(command: "LPOP", with: [key])
    }

    /// Pushes all of the provided elements into a list.
    /// - Note: This inserts the elements at the head of the list; for the tail see `rpush(_:into:)`.
    ///
    /// See [https://redis.io/commands/lpush](https://redis.io/commands/lpush)
    /// - Parameters:
    ///     - elements: The values to push into the list.
    ///     - key: The key of the list.
    /// - Returns: The length of the list after adding the new elements.
    @inlinable
    public func lpush(_ elements: [RESPValueConvertible], into key: String) -> EventLoopFuture<Int> {
        assert(elements.count > 0, "At least 1 element should be provided.")
        
        return send(command: "LPUSH", with: [key] + elements)
            .mapFromRESP()
    }

    /// Pushes an element into a list, but only if the key exists and holds a list.
    /// - Note: This inserts the element at the head of the list, for the tail see `rpushx(_:into:)`.
    ///
    /// See [https://redis.io/commands/lpushx](https://redis.io/commands/lpushx)
    /// - Parameters:
    ///     - element: The value to try and push into the list.
    ///     - key: The key of the list.
    /// - Returns: The length of the list after adding the new elements.
    @inlinable
    public func lpushx(_ element: RESPValueConvertible, into key: String) -> EventLoopFuture<Int> {
        return send(command: "LPUSHX", with: [key, element])
            .mapFromRESP()
    }
}

// MARK: Tail Operations

extension RedisClient {
    /// Removes the last element a list.
    ///
    /// See [https://redis.io/commands/rpop](https://redis.io/commands/rpop)
    /// - Parameter key: The key of the list to pop from.
    /// - Returns: The element that was popped from the list, else `.null`.
    @inlinable
    public func rpop(from key: String) -> EventLoopFuture<RESPValue> {
        return send(command: "RPOP", with: [key])
    }

    /// Pushes all of the provided elements into a list.
    /// - Note: This inserts the elements at the tail of the list; for the head see `lpush(_:into:)`.
    ///
    /// See [https://redis.io/commands/rpush](https://redis.io/commands/rpush)
    ///     - elements: The values to push into the list.
    ///     - key: The key of the list.
    /// - Returns: The length of the list after adding the new elements.
    @inlinable
    public func rpush(_ elements: [RESPValueConvertible], into key: String) -> EventLoopFuture<Int> {
        assert(elements.count > 0, "At least 1 element should be provided.")

        return send(command: "RPUSH", with: [key] + elements)
            .mapFromRESP()
    }

    /// Pushes an element into a list, but only if the key exists and holds a list.
    /// - Note: This inserts the element at the tail of the list; for the head see `lpushx(_:into:)`.
    ///
    /// See [https://redis.io/commands/rpushx](https://redis.io/commands/rpushx)
    /// - Parameters:
    ///     - element: The value to try and push into the list.
    ///     - key: The key of the list.
    /// - Returns: The length of the list after adding the new elements.
    @inlinable
    public func rpushx(_ element: RESPValueConvertible, into key: String) -> EventLoopFuture<Int> {
        return send(command: "RPUSHX", with: [key, element])
            .mapFromRESP()
    }
}
