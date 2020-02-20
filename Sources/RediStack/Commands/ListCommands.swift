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
    /// Gets the length of a list.
    ///
    /// See [https://redis.io/commands/llen](https://redis.io/commands/llen)
    /// - Parameter key: The key of the list.
    /// - Returns: The number of elements in the list.
    @inlinable
    public func llen(of key: RedisKey) -> EventLoopFuture<Int> {
        let args = [RESPValue(bulk: key)]
        return send(command: "LLEN", with: args)
            .map()
    }

    /// Gets the element from a list stored at the provided index position.
    ///
    /// See [https://redis.io/commands/lindex](https://redis.io/commands/lindex)
    /// - Parameters:
    ///     - index: The 0-based index of the element to get.
    ///     - key: The key of the list.
    /// - Returns: The element stored at index, or `.null` if out of bounds.
    @inlinable
    public func lindex(_ index: Int, from key: RedisKey) -> EventLoopFuture<RESPValue> {
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: index)
        ]
        return send(command: "LINDEX", with: args)
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
    public func lset<Value: RESPValueConvertible>(
        index: Int,
        to value: Value,
        in key: RedisKey
    ) -> EventLoopFuture<Void> {
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: index),
            value.convertedToRESPValue()
        ]
        return send(command: "LSET", with: args)
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
    public func lrem<Value: RESPValueConvertible>(
        _ value: Value,
        from key: RedisKey,
        count: Int = 0
    ) -> EventLoopFuture<Int> {
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: count),
            value.convertedToRESPValue()
        ]
        return send(command: "LREM", with: args)
            .map()
    }
}

// MARK: LTrim

extension RedisClient {
    /// Trims a List to only contain elements within the specified inclusive bounds of 0-based indices.
    ///
    /// See [https://redis.io/commands/ltrim](https://redis.io/commands/ltrim)
    /// - Parameters:
    ///     - key: The key of the List to trim.
    ///     - start: The index of the first element to keep.
    ///     - stop: The index of the last element to keep.
    /// - Returns: A `NIO.EventLoopFuture` that resolves when the operation has succeeded, or fails with a `RedisError`.
    @inlinable
    public func ltrim(_ key: RedisKey, before start: Int, after stop: Int) -> EventLoopFuture<Void> {
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: start),
            .init(bulk: stop)
        ]
        return send(command: "LTRIM", with: args)
            .map { _ in () }
    }
    
    /// Trims a List to only contain elements within the specified inclusive bounds of 0-based indices.
    ///
    /// To keep elements 4 through 7:
    /// ```swift
    /// client.ltrim("myList", keepingIndices: 3...6)
    /// ```
    ///
    /// To keep the last 4 through 7 elements:
    /// ```swift
    /// client.ltrim("myList", keepingIndices: (-7)...(-4))
    /// ```
    ///
    /// To keep the first and last 4 elements:
    /// ```swift
    /// client.ltrim("myList", keepingIndices: (-4)...3)
    /// ```
    ///
    /// See [https://redis.io/commands/ltrim](https://redis.io/commands/ltrim)
    /// - Warning: A `ClosedRange` cannot be created where `upperBound` is less than `lowerBound`; so while Redis may support `0...-1`,
    ///     `ClosedRange` will trigger a precondition failure.
    ///
    ///     If you need such a range, use `ltrim(_:before:after:)` instead.
    /// - Parameters:
    ///     - key: The key of the List to trim.
    ///     - range: The range of indices that should be kept in the List.
    /// - Returns: A `NIO.EventLoopFuture` that resolves when the operation has succeeded, or fails with a `RedisError`.
    @inlinable
    public func ltrim(_ key: RedisKey, keepingIndices range: ClosedRange<Int>) -> EventLoopFuture<Void> {
        return self.ltrim(key, before: range.lowerBound, after: range.upperBound)
    }

    /// Trims a List to only contain elements starting from the specified index.
    ///
    /// To keep all but the first 3 elements:
    /// ```swift
    /// client.ltrim("myList", keepingIndices: 3...)
    /// ```
    ///
    /// To keep the last 4 elements:
    /// ```swift
    /// client.ltrim("myList", keepingIndices: (-4)...)
    /// ```
    ///
    /// See [https://redis.io/commands/ltrim](https://redis.io/commands/ltrim)
    /// - Parameters:
    ///     - key: The key of the List to trim.
    ///     - range: The range of indices that should be kept in the List.
    /// - Returns: A `NIO.EventLoopFuture` that resolves when the operation has succeeded, or fails with a `RedisError`.
    @inlinable
    public func ltrim(_ key: RedisKey, keepingIndices range: PartialRangeFrom<Int>) -> EventLoopFuture<Void> {
        return self.ltrim(key, before: range.lowerBound, after: -1)
    }
    
    /// Trims a List to only contain elements before the specified index.
    ///
    /// To keep the first 3 elements:
    /// ```swift
    /// client.ltrim("myList", keepingIndices: ..<3)
    /// ```
    ///
    /// To keep all but the last 4 elements:
    /// ```swift
    /// client.ltrim("myList", keepingIndices: ..<(-4))
    /// ```
    ///
    /// See [https://redis.io/commands/ltrim](https://redis.io/commands/ltrim)
    /// - Parameters:
    ///     - key: The key of the List to trim.
    ///     - range: The range of indices that should be kept in the List.
    /// - Returns: A `NIO.EventLoopFuture` that resolves when the operation has succeeded, or fails with a `RedisError`.
    @inlinable
    public func ltrim(_ key: RedisKey, keepingIndices range: PartialRangeUpTo<Int>) -> EventLoopFuture<Void> {
        return self.ltrim(key, before: 0, after: range.upperBound - 1)
    }
    
    /// Trims a List to only contain elements up to the specified index.
    ///
    /// To keep the first 4 elements:
    /// ```swift
    /// client.ltrim("myList", keepingIndices: ...3)
    /// ```
    ///
    /// To keep all but the last 3 elements:
    /// ```swift
    /// client.ltrim("myList", keepingIndices: ...(-4))
    /// ```
    ///
    /// See [https://redis.io/commands/ltrim](https://redis.io/commands/ltrim)
    /// - Parameters:
    ///     - key: The key of the List to trim.
    ///     - range: The range of indices that should be kept in the List.
    /// - Returns: A `NIO.EventLoopFuture` that resolves when the operation has succeeded, or fails with a `RedisError`.
    @inlinable
    public func ltrim(_ key: RedisKey, keepingIndices range: PartialRangeThrough<Int>) -> EventLoopFuture<Void> {
        return self.ltrim(key, before: 0, after: range.upperBound)
    }
    
    /// Trims a List to only contain the elements from the specified index up to the index provided.
    ///
    /// To keep the first 4 elements:
    /// ```swift
    /// client.ltrim("myList", keepingIndices: 0..<4)
    /// ```
    ///
    /// To keep all but the last 3 elements:
    /// ```swift
    /// client.ltrim("myList", keepingIndices: 0..<(-3))
    /// ```
    ///
    /// See [https://redis.io/commands/ltrim](https://redis.io/commands/ltrim)
    /// - Warning: A `Range` cannot be created where `upperBound` is less than `lowerBound`; so while Redis may support `0..<(-1)`,
    ///     `Range` will trigger a precondition failure.
    ///
    ///     If you need such a range, use `ltrim(_:before:after:)` instead.
    /// - Parameters:
    ///     - key: The key of the List to trim.
    ///     - range: The range of indices that should be kept in the List.
    /// - Returns: A `NIO.EventLoopFuture` that resolves when the operation has succeeded, or fails with a `RedisError`.
    @inlinable
    public func ltrim(_ key: RedisKey, keepingIndices range: Range<Int>) -> EventLoopFuture<Void> {
        return self.ltrim(key, before: range.lowerBound, after: range.upperBound - 1)
    }
}

// MARK: LRange

extension RedisClient {
    /// Gets all elements from a List within the the specified inclusive bounds of 0-based indices.
    ///
    /// See [https://redis.io/commands/lrange](https://redis.io/commands/lrange)
    /// - Parameters:
    ///     - key: The key of the List.
    ///     - firstIndex: The index of the first element to include in the range of elements returned.
    ///     - lastIndex: The index of the last element to include in the range of elements returned.
    /// - Returns: An array of elements found within the range specified.
    @inlinable
    public func lrange(from key: RedisKey, firstIndex: Int, lastIndex: Int) -> EventLoopFuture<[RESPValue]> {
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: firstIndex),
            .init(bulk: lastIndex)
        ]
        return send(command: "LRANGE", with: args)
            .map()
    }
    
    /// Gets all elements from a List within the specified inclusive bounds of 0-based indices.
    ///
    /// To get the elements at index 4 through 7:
    /// ```swift
    /// client.lrange(from: "myList", indices: 4...7)
    /// ```
    ///
    /// To get the last 4 elements:
    /// ```swift
    /// client.lrange(from: "myList", indices: (-4)...(-1))
    /// ```
    ///
    /// To get the first and last 4 elements:
    /// ```swift
    /// client.lrange(from: "myList", indices: (-4)...3)
    /// ```
    ///
    /// To get the first element, and the last 4:
    /// ```swift
    /// client.lrange(from: "myList", indices: (-4)...0))
    /// ```
    ///
    /// See [https://redis.io/commands/lrange](https://redis.io/commands/lrange)
    /// - Warning: A `ClosedRange` cannot be created where `upperBound` is less than `lowerBound`; so while Redis may support `0...-1`,
    ///     `ClosedRange` will trigger a precondition failure.
    ///
    ///     If you need such a range, use `lrange(from:firstIndex:lastIndex:)` instead.
    /// - Parameters:
    ///     - key: The key of the List to return elements from.
    ///     - range: The range of inclusive indices of elements to get.
    /// - Returns: An array of elements found within the range specified.
    @inlinable
    public func lrange(from key: RedisKey, indices range: ClosedRange<Int>) -> EventLoopFuture<[RESPValue]> {
        return self.lrange(from: key, firstIndex: range.lowerBound, lastIndex: range.upperBound)
    }
    
    /// Gets all the elements from a List starting with the first index bound up to, but not including, the element at the last index bound.
    ///
    /// To get the elements at index 4 through 7:
    /// ```swift
    /// client.lrange(from: "myList", indices: 4..<8)
    /// ```
    ///
    /// To get the last 4 elements:
    /// ```swift
    /// client.lrange(from: "myList", indices: (-4)..<0)
    /// ```
    ///
    /// To get the first and last 4 elements:
    /// ```swift
    /// client.lrange(from: "myList", indices: (-4)..<4)
    /// ```
    ///
    /// To get the first element, and the last 4:
    /// ```swift
    /// client.lrange(from: "myList", indices: (-4)..<1)
    /// ```
    ///
    /// See [https://redis.io/commands/lrange](https://redis.io/commands/lrange)
    /// - Warning: A `Range` cannot be created where `upperBound` is less than `lowerBound`; so while Redis may support `0..<(-1)`,
    ///     `Range` will trigger a precondition failure.
    ///
    ///     If you need such a range, use `lrange(from:firstIndex:lastIndex:)` instead.
    /// - Parameters:
    ///     - key: The key of the List to return elements from.
    ///     - range: The range of indices (inclusive lower, exclusive upper) elements to get.
    /// - Returns: An array of elements found within the range specified.
    @inlinable
    public func lrange(from key: RedisKey, indices range: Range<Int>) -> EventLoopFuture<[RESPValue]> {
        return self.lrange(from: key, firstIndex: range.lowerBound, lastIndex: range.upperBound - 1)
    }

    /// Gets all elements from the index specified to the end of a List.
    ///
    /// To get all except the first 2 elements of a List:
    /// ```swift
    /// client.lrange(from: "myList", fromIndex: 2)
    /// ```
    ///
    /// To get the last 4 elements of a List:
    /// ```swift
    /// client.lrange(from: "myList", fromIndex: -4)
    /// ```
    ///
    /// See `lrange(from:indices:)`, `lrange(from:firstIndex:lastIndex:)`, and [https://redis.io/commands/lrange](https://redis.io/commands/lrange)
    /// - Parameters:
    ///     - key: The key of the List to return elements from.
    ///     - index: The index of the first element that will be in the returned values.
    /// - Returns: An array of elements from the List between the index and the end.
    @inlinable
    public func lrange(from key: RedisKey, fromIndex index: Int) -> EventLoopFuture<[RESPValue]> {
        return self.lrange(from: key, firstIndex: index, lastIndex: -1)
    }
    
    /// Gets all elements from the the start of a List up to, and including, the element at the index specified.
    ///
    /// To get the first 3 elements of a List:
    /// ```swift
    /// client.lrange(from: "myList", throughIndex: 2)
    /// ```
    ///
    /// To get all except the last 3 elements of a List:
    /// ```swift
    /// client.lrange(from: "myList", throughIndex: -4)
    /// ```
    ///
    /// See `lrange(from:indices:)`, `lrange(from:firstIndex:lastIndex:)`, and [https://redis.io/commands/lrange](https://redis.io/commands/lrange)
    /// - Parameters:
    ///     - key: The key of the List to return elements from.
    ///     - index: The index of the last element that will be in the returned values.
    /// - Returns: An array of elements from the start of a List to the index.
    @inlinable
    public func lrange(from key: RedisKey, throughIndex index: Int) -> EventLoopFuture<[RESPValue]> {
        return self.lrange(from: key, firstIndex: 0, lastIndex: index)
    }
    
    /// Gets all elements from the the start of a List up to, but not including, the element at the index specified.
    ///
    /// To get the first 3 elements of a List:
    /// ```swift
    /// client.lrange(from: "myList", upToIndex: 3)
    /// ```
    ///
    /// To get all except the last 3 elements of a List:
    /// ```swift
    /// client.lrange(from: "myList", upToIndex: -3)
    /// ```
    ///
    /// See `lrange(from:indices:)`, `lrange(from:firstIndex:lastIndex:)`, and [https://redis.io/commands/lrange](https://redis.io/commands/lrange)
    /// - Parameters:
    ///     - key: The key of the List to return elements from.
    ///     - index: The index of the element to not include in the returned values.
    /// - Returns: An array of elements from the start of the List and up to the index.
    @inlinable
    public func lrange(from key: RedisKey, upToIndex index: Int) -> EventLoopFuture<[RESPValue]> {
        return self.lrange(from: key, firstIndex: 0, lastIndex: index - 1)
    }
}

// MARK: Pop & Push

extension RedisClient {
    /// Pops the last element from a source list and pushes it to a destination list.
    ///
    /// See [https://redis.io/commands/rpoplpush](https://redis.io/commands/rpoplpush)
    /// - Parameters:
    ///     - source: The key of the list to pop from.
    ///     - dest: The key of the list to push to.
    /// - Returns: The element that was moved.
    @inlinable
    public func rpoplpush(from source: RedisKey, to dest: RedisKey) -> EventLoopFuture<RESPValue> {
        let args: [RESPValue] = [
            .init(bulk: source),
            .init(bulk: dest)
        ]
        return send(command: "RPOPLPUSH", with: args)
    }

    /// Pops the last element from a source list and pushes it to a destination list, blocking until
    /// an element is available from the source list.
    ///
    /// - Important:
    ///     This will block the connection from completing further commands until an element
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
    /// - Returns: The element popped from the source list and pushed to the destination,
    ///     or `nil` if the timeout was reached.
    @inlinable
    public func brpoplpush(
        from source: RedisKey,
        to dest: RedisKey,
        timeout: TimeAmount = .seconds(0)
    ) -> EventLoopFuture<RESPValue?> {
        let args: [RESPValue] = [
            .init(bulk: source),
            .init(bulk: dest),
            .init(bulk: timeout.seconds)
        ]
        return send(command: "BRPOPLPUSH", with: args)
            .map { $0.isNull ? nil: $0 }
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
    public func linsert<Value: RESPValueConvertible>(
        _ element: Value,
        into key: RedisKey,
        before pivot: Value
    ) -> EventLoopFuture<Int> {
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
    public func linsert<Value: RESPValueConvertible>(
        _ element: Value,
        into key: RedisKey,
        after pivot: Value
    ) -> EventLoopFuture<Int> {
        return _linsert(pivotKeyword: "AFTER", element, key, pivot)
    }

    @usableFromInline
    func _linsert<Value: RESPValueConvertible>(
        pivotKeyword: String,
        _ element: Value,
        _ key: RedisKey,
        _ pivot: Value
    ) -> EventLoopFuture<Int> {
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: pivotKeyword),
            pivot.convertedToRESPValue(),
            element.convertedToRESPValue()
        ]
        return send(command: "LINSERT", with: args)
            .map()
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
    public func lpop(from key: RedisKey) -> EventLoopFuture<RESPValue> {
        let args = [RESPValue(bulk: key)]
        return send(command: "LPOP", with: args)
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
    public func lpush<Value: RESPValueConvertible>(_ elements: [Value], into key: RedisKey) -> EventLoopFuture<Int> {
        assert(elements.count > 0, "At least 1 element should be provided.")
        
        var args: [RESPValue] = [.init(bulk: key)]
        args.append(convertingContentsOf: elements)
        
        return send(command: "LPUSH", with: args)
            .map()
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
    public func lpush<Value: RESPValueConvertible>(_ elements: Value..., into key: RedisKey) -> EventLoopFuture<Int> {
        return self.lpush(elements, into: key)
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
    public func lpushx<Value: RESPValueConvertible>(_ element: Value, into key: RedisKey) -> EventLoopFuture<Int> {
        let args: [RESPValue] = [
            .init(bulk: key),
            element.convertedToRESPValue()
        ]
        return send(command: "LPUSHX", with: args)
            .map()
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
    public func rpop(from key: RedisKey) -> EventLoopFuture<RESPValue> {
        let args = [RESPValue(bulk: key)]
        return send(command: "RPOP", with: args)
    }

    /// Pushes all of the provided elements into a list.
    /// - Note: This inserts the elements at the tail of the list; for the head see `lpush(_:into:)`.
    ///
    /// See [https://redis.io/commands/rpush](https://redis.io/commands/rpush)
    ///     - elements: The values to push into the list.
    ///     - key: The key of the list.
    /// - Returns: The length of the list after adding the new elements.
    @inlinable
    public func rpush<Value: RESPValueConvertible>(_ elements: [Value], into key: RedisKey) -> EventLoopFuture<Int> {
        assert(elements.count > 0, "At least 1 element should be provided.")

        var args: [RESPValue] = [.init(bulk: key)]
        args.append(convertingContentsOf: elements)
        
        return send(command: "RPUSH", with: args)
            .map()
    }
    
    /// Pushes all of the provided elements into a list.
    /// - Note: This inserts the elements at the tail of the list; for the head see `lpush(_:into:)`.
    ///
    /// See [https://redis.io/commands/rpush](https://redis.io/commands/rpush)
    ///     - elements: The values to push into the list.
    ///     - key: The key of the list.
    /// - Returns: The length of the list after adding the new elements.
    @inlinable
    public func rpush<Value: RESPValueConvertible>(_ elements: Value..., into key: RedisKey) -> EventLoopFuture<Int> {
        return self.rpush(elements, into: key)
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
    public func rpushx<Value: RESPValueConvertible>(_ element: Value, into key: RedisKey) -> EventLoopFuture<Int> {
        let args: [RESPValue] = [
            .init(bulk: key),
            element.convertedToRESPValue()
        ]
        return send(command: "RPUSHX", with: args)
            .map()
    }
}

// MARK: Blocking Pop

extension RedisClient {
    /// Removes the first element of a list, blocking until an element is available.
    ///
    /// - Important:
    ///     This will block the connection from completing further commands until an element
    ///     is available to pop from the list.
    ///
    ///     It is **highly** recommended to set a reasonable `timeout`
    ///     or to use the non-blocking `lpop` method where possible.
    ///
    /// See [https://redis.io/commands/blpop](https://redis.io/commands/blpop)
    /// - Parameters:
    ///     - key: The key of the list to pop from.
    ///     - timeout: The max time to wait for a value to use. `0`seconds means to wait indefinitely.
    /// - Returns: The element that was popped from the list, or `nil` if the timout was reached.
    @inlinable
    public func blpop(from key: RedisKey, timeout: TimeAmount = .seconds(0)) -> EventLoopFuture<RESPValue?> {
        return blpop(from: [key], timeout: timeout)
            .map { $0?.1 }
    }

    /// Removes the first element of a list, blocking until an element is available.
    ///
    /// - Important:
    ///     This will block the connection from completing further commands until an element
    ///     is available to pop from the group of lists.
    ///
    ///     It is **highly** recommended to set a reasonable `timeout`
    ///     or to use the non-blocking `lpop` method where possible.
    ///
    /// See [https://redis.io/commands/blpop](https://redis.io/commands/blpop)
    /// - Parameters:
    ///     - keys: The keys of lists in Redis that should be popped from.
    ///     - timeout: The max time to wait for a value to use. `0`seconds means to wait indefinitely.
    /// - Returns:
    ///     If timeout was reached, `nil`.
    ///
    ///     Otherwise, the key of the list the element was removed from and the popped element.
    @inlinable
    public func blpop(from keys: [RedisKey], timeout: TimeAmount = .seconds(0)) -> EventLoopFuture<(RedisKey, RESPValue)?> {
        return _bpop(command: "BLPOP", keys, timeout)
    }
    
    /// Removes the first element of a list, blocking until an element is available.
    ///
    /// - Important:
    ///     This will block the connection from completing further commands until an element
    ///     is available to pop from the group of lists.
    ///
    ///     It is **highly** recommended to set a reasonable `timeout`
    ///     or to use the non-blocking `lpop` method where possible.
    ///
    /// See [https://redis.io/commands/blpop](https://redis.io/commands/blpop)
    /// - Parameters:
    ///     - keys: The keys of lists in Redis that should be popped from.
    ///     - timeout: The max time to wait for a value to use. `0`seconds means to wait indefinitely.
    /// - Returns:
    ///     If timeout was reached, `nil`.
    ///
    ///     Otherwise, the key of the list the element was removed from and the popped element.
    @inlinable
    public func blpop(from keys: RedisKey..., timeout: TimeAmount = .seconds(0)) -> EventLoopFuture<(RedisKey, RESPValue)?> {
        return self.blpop(from: keys, timeout: timeout)
    }

    /// Removes the last element of a list, blocking until an element is available.
    ///
    /// - Important:
    ///     This will block the connection from completing further commands until an element
    ///     is available to pop from the list.
    ///
    ///     It is **highly** recommended to set a reasonable `timeout`
    ///     or to use the non-blocking `rpop` method where possible.
    ///
    /// See [https://redis.io/commands/brpop](https://redis.io/commands/brpop)
    /// - Parameters:
    ///     - key: The key of the list to pop from.
    ///     - timeout: The max time to wait for a value to use. `0`seconds means to wait indefinitely.
    /// - Returns: The element that was popped from the list, or `nil` if the timout was reached.
    @inlinable
    public func brpop(from key: RedisKey, timeout: TimeAmount = .seconds(0)) -> EventLoopFuture<RESPValue?> {
        return brpop(from: [key], timeout: timeout)
            .map { $0?.1 }
    }

    /// Removes the last element of a list, blocking until an element is available.
    ///
    /// - Important:
    ///     This will block the connection from completing further commands until an element
    ///     is available to pop from the group of lists.
    ///
    ///     It is **highly** recommended to set a reasonable `timeout`
    ///     or to use the non-blocking `rpop` method where possible.
    ///
    /// See [https://redis.io/commands/brpop](https://redis.io/commands/brpop)
    /// - Parameters:
    ///     - keys: The keys of lists in Redis that should be popped from.
    ///     - timeout: The max time to wait for a value to use. `0`seconds means to wait indefinitely.
    /// - Returns:
    ///     If timeout was reached, `nil`.
    ///
    ///     Otherwise, the key of the list the element was removed from and the popped element.
    @inlinable
    public func brpop(from keys: [RedisKey], timeout: TimeAmount = .seconds(0)) -> EventLoopFuture<(RedisKey, RESPValue)?> {
        return _bpop(command: "BRPOP", keys, timeout)
    }

    /// Removes the last element of a list, blocking until an element is available.
    ///
    /// - Important:
    ///     This will block the connection from completing further commands until an element
    ///     is available to pop from the group of lists.
    ///
    ///     It is **highly** recommended to set a reasonable `timeout`
    ///     or to use the non-blocking `rpop` method where possible.
    ///
    /// See [https://redis.io/commands/brpop](https://redis.io/commands/brpop)
    /// - Parameters:
    ///     - keys: The keys of lists in Redis that should be popped from.
    ///     - timeout: The max time to wait for a value to use. `0`seconds means to wait indefinitely.
    /// - Returns:
    ///     If timeout was reached, `nil`.
    ///
    ///     Otherwise, the key of the list the element was removed from and the popped element.
    @inlinable
    public func brpop(from keys: RedisKey..., timeout: TimeAmount = .seconds(0)) -> EventLoopFuture<(RedisKey, RESPValue)?> {
        return self.brpop(from: keys, timeout: timeout)
    }

    @usableFromInline
    func _bpop(
        command: String,
        _ keys: [RedisKey],
        _ timeout: TimeAmount
    ) -> EventLoopFuture<(RedisKey, RESPValue)?> {
        var args = keys.map(RESPValue.init)
        args.append(.init(bulk: timeout.seconds))
        
        return send(command: command, with: args)
            .flatMapThrowing {
                guard !$0.isNull else { return nil }
                guard let response = [RESPValue](fromRESP: $0) else {
                    throw RedisClientError.failedRESPConversion(to: [RESPValue].self)
                }
                assert(response.count == 2, "Unexpected response size returned!")
                guard let key = response[0].string else {
                    throw RedisClientError.assertionFailure(message: "Unexpected structure in response: \(response)")
                }
                return (.init(key), response[1])
            }
    }
}
