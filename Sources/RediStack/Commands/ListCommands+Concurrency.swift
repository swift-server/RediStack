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

import NIOCore

// MARK: General

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension RedisClient {
    /// Gets the length of a list.
    ///
    /// See [https://redis.io/commands/llen](https://redis.io/commands/llen)
    /// - Parameter key: The key of the list.
    /// - Returns: The number of elements in the list.
    public func llen(of key: RedisKey) async throws -> Int {
        try await llen(of: key).get()
    }

    /// Gets the element from a list stored at the provided index position.
    ///
    /// See [https://redis.io/commands/lindex](https://redis.io/commands/lindex)
    /// - Parameters:
    ///     - index: The 0-based index of the element to get.
    ///     - key: The key of the list.
    /// - Returns: The element stored at index, or `.null` if out of bounds.
    public func lindex(_ index: Int, from key: RedisKey) async throws -> RESPValue {
        try await lindex(index, from: key).get()
    }

    /// Gets the element from a list stored at the provided index position.
    ///
    /// See [https://redis.io/commands/lindex](https://redis.io/commands/lindex)
    /// - Parameters:
    ///     - index: The 0-based index of the element to get.
    ///     - key: The key of the list.
    ///     - type: The type to convert the value to.
    /// - Returns: The element stored at index. If the value fails the `RESPValue` conversion or if the index is out of bounds, the returned value will be `nil`.
    @inlinable
    public func lindex<Value: RESPValueConvertible>(
        _ index: Int,
        from key: RedisKey,
        as type: Value.Type
    ) async throws -> Value? {
        try await lindex(index, from: key, as: type).get()
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
    ) async throws {
        try await lset(index: index, to: value, in: key).get()
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
    ) async throws -> Int {
        try await lrem(value, from: key, count: count).get()
    }
}

// MARK: LTrim

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension RedisClient {
    /// Trims a List to only contain elements within the specified inclusive bounds of 0-based indices.
    ///
    /// See [https://redis.io/commands/ltrim](https://redis.io/commands/ltrim)
    /// - Parameters:
    ///     - key: The key of the List to trim.
    ///     - start: The index of the first element to keep.
    ///     - stop: The index of the last element to keep.
    public func ltrim(_ key: RedisKey, before start: Int, after stop: Int) async throws {
        try await ltrim(key, before: start, after: stop).get()
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
    public func ltrim(_ key: RedisKey, keepingIndices range: ClosedRange<Int>) async throws {
        try await ltrim(key, keepingIndices: range).get()
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
    public func ltrim(_ key: RedisKey, keepingIndices range: PartialRangeFrom<Int>) async throws {
        try await ltrim(key, keepingIndices: range).get()
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
    public func ltrim(_ key: RedisKey, keepingIndices range: PartialRangeUpTo<Int>) async throws {
        try await ltrim(key, keepingIndices: range).get()
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
    public func ltrim(_ key: RedisKey, keepingIndices range: PartialRangeThrough<Int>) async throws {
        try await ltrim(key, keepingIndices: range).get()
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
    public func ltrim(_ key: RedisKey, keepingIndices range: Range<Int>) async throws {
        try await ltrim(key, keepingIndices: range).get()
    }
}

// MARK: LRange

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension RedisClient {
    /// Gets all elements from a List within the the specified inclusive bounds of 0-based indices.
    ///
    /// See [https://redis.io/commands/lrange](https://redis.io/commands/lrange)
    /// - Parameters:
    ///     - key: The key of the List.
    ///     - firstIndex: The index of the first element to include in the range of elements returned.
    ///     - lastIndex: The index of the last element to include in the range of elements returned.
    /// - Returns: An array of elements found within the range specified.
    public func lrange(from key: RedisKey, firstIndex: Int, lastIndex: Int) async throws -> [RESPValue] {
        try await lrange(from: key, firstIndex: firstIndex, lastIndex: lastIndex).get()
    }

    /// Gets all elements from a List within the the specified inclusive bounds of 0-based indices.
    ///
    /// See [https://redis.io/commands/lrange](https://redis.io/commands/lrange)
    /// - Parameters:
    ///     - key: The key of the List.
    ///     - firstIndex: The index of the first element to include in the range of elements returned.
    ///     - lastIndex: The index of the last element to include in the range of elements returned.
    ///     - type: The type to convert the values to.
    /// - Returns: An array of elements found within the range specified, otherwise `nil` if the `RESPValue` conversion failed.
    @inlinable
    public func lrange<Value: RESPValueConvertible>(
        from key: RedisKey,
        firstIndex: Int,
        lastIndex: Int,
        as type: Value.Type
    ) async throws -> [Value?] {
        try await lrange(from: key, firstIndex: firstIndex, lastIndex: lastIndex, as: type).get()
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
    public func lrange(from key: RedisKey, indices range: ClosedRange<Int>) async throws -> [RESPValue] {
        try await lrange(from: key, indices: range).get()
    }

    /// Gets all elements from a List within the specified inclusive bounds of 0-based indices.
    ///
    /// See [https://redis.io/commands/lrange](https://redis.io/commands/lrange).
    /// - Warning: A `ClosedRange` cannot be created where `upperBound` is less than `lowerBound`; so while Redis may support `0...-1`,
    ///     `ClosedRange` will trigger a precondition failure.
    ///
    ///     If you need such a range, use `lrange(from:firstIndex:lastIndex:)` instead.
    /// - Parameters:
    ///     - key: The key of the List to return elements from.
    ///     - range: The range of inclusive indices of elements to get.
    ///     - type: The type to convert the values to.
    /// - Returns: An array of elements found within the range specified, otherwise `nil` if the `RESPValue` conversion failed.
    @inlinable
    public func lrange<Value: RESPValueConvertible>(
        from key: RedisKey,
        indices range: ClosedRange<Int>,
        as type: Value.Type
    ) async throws -> [Value?] {
        try await lrange(from: key, indices: range, as: type).get()
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
    public func lrange(from key: RedisKey, indices range: Range<Int>) async throws -> [RESPValue] {
        try await lrange(from: key, indices: range).get()
    }

    /// Gets all the elements from a List starting with the first index bound up to, but not including, the element at the last index bound.
    ///
    /// See [https://redis.io/commands/lrange](https://redis.io/commands/lrange)
    /// - Warning: A `Range` cannot be created where `upperBound` is less than `lowerBound`; so while Redis may support `0..<(-1)`,
    ///     `Range` will trigger a precondition failure.
    ///
    ///     If you need such a range, use `lrange(from:firstIndex:lastIndex:)` instead.
    /// - Parameters:
    ///     - key: The key of the List to return elements from.
    ///     - range: The range of indices (inclusive lower, exclusive upper) elements to get.
    ///     - type: The type to convert the values to.
    /// - Returns: An array of elements found within the range specified, otherwise `nil` if the `RESPValue` conversion failed.
    @inlinable
    public func lrange<Value: RESPValueConvertible>(
        from key: RedisKey,
        indices range: Range<Int>,
        as type: Value.Type
    ) async throws -> [Value?] {
        try await lrange(from: key, indices: range, as: type).get()
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
    public func lrange(from key: RedisKey, fromIndex index: Int) async throws -> [RESPValue] {
        try await lrange(from: key, fromIndex: index).get()
    }

    /// Gets all elements from the index specified to the end of a List.
    ///
    /// See `lrange(from:indices:)`, `lrange(from:firstIndex:lastIndex:)`, and [https://redis.io/commands/lrange](https://redis.io/commands/lrange)
    /// - Parameters:
    ///     - key: The key of the List to return elements from.
    ///     - index: The index of the first element that will be in the returned values.
    ///     - type: The type to convert the values to.
    /// - Returns: An array of elements from the List between the index and the end, otherwise `nil` if the `RESPValue` conversion failed.
    @inlinable
    public func lrange<Value: RESPValueConvertible>(
        from key: RedisKey,
        fromIndex index: Int,
        as type: Value.Type
    ) async throws -> [Value?] {
        try await lrange(from: key, fromIndex: index, as: type).get()
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
    public func lrange(from key: RedisKey, throughIndex index: Int) async throws -> [RESPValue] {
        try await lrange(from: key, throughIndex: index).get()
    }

    /// Gets all elements from the the start of a List up to, and including, the element at the index specified.
    ///
    /// See `lrange(from:indices:)`, `lrange(from:firstIndex:lastIndex:)`, and [https://redis.io/commands/lrange](https://redis.io/commands/lrange)
    /// - Parameters:
    ///     - key: The key of the List to return elements from.
    ///     - index: The index of the last element that will be in the returned values.
    ///     - type: The type to convert the values to.
    /// - Returns: An array of elements from the start of a List to the index, otherwise `nil` if the `RESPValue` conversion failed.
    @inlinable
    public func lrange<Value: RESPValueConvertible>(
        from key: RedisKey,
        throughIndex index: Int,
        as type: Value.Type
    ) async throws -> [Value?] {
        try await lrange(from: key, throughIndex: index, as: type).get()
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
    public func lrange(from key: RedisKey, upToIndex index: Int) async throws -> [RESPValue] {
        try await lrange(from: key, upToIndex: index).get()
    }

    /// Gets all elements from the the start of a List up to, but not including, the element at the index specified.
    ///
    /// See `lrange(from:indices:)`, `lrange(from:firstIndex:lastIndex:)`, and [https://redis.io/commands/lrange](https://redis.io/commands/lrange)
    /// - Parameters:
    ///     - key: The key of the List to return elements from.
    ///     - index: The index of the element to not include in the returned values.
    ///     - type: The type to convert the values to.
    /// - Returns: An array of elements from the start of the List and up to the index, otherwise `nil` if the `RESPValue` conversion failed.
    @inlinable
    public func lrange<Value: RESPValueConvertible>(
        from key: RedisKey,
        upToIndex index: Int,
        as type: Value.Type
    ) async throws -> [Value?] {
        try await lrange(from: key, upToIndex: index, as: type).get()
    }
}

// MARK: Pop & Push

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension RedisClient {
    /// Pops the last element from a source list and pushes it to a destination list.
    ///
    /// See [https://redis.io/commands/rpoplpush](https://redis.io/commands/rpoplpush)
    /// - Parameters:
    ///     - source: The key of the list to pop from.
    ///     - dest: The key of the list to push to.
    /// - Returns: The element that was moved.
    public func rpoplpush(from source: RedisKey, to dest: RedisKey) async throws -> RESPValue {
        try await rpoplpush(from: source, to: dest).get()
    }

    /// Pops the last element from a source list and pushes it to a destination list.
    ///
    /// See [https://redis.io/commands/rpoplpush](https://redis.io/commands/rpoplpush)
    /// - Parameters:
    ///     - source: The key of the list to pop from.
    ///     - dest: The key of the list to push to.
    ///     - type: The type to convert the value to.
    /// - Returns: The element that was moved. This value is `nil` if the `RESPValue` conversion failed.
    @inlinable
    public func rpoplpush<Value: RESPValueConvertible>(
        from source: RedisKey,
        to dest: RedisKey,
        valueType: Value.Type
    ) async throws -> Value? {
        try await rpoplpush(from: source, to: dest, valueType: valueType).get()
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
    /// - Returns: The element popped from the source list and pushed to the destination or `.null` if the timeout was reached.
    public func brpoplpush(
        from source: RedisKey,
        to dest: RedisKey,
        timeout: TimeAmount = .seconds(0)
    ) async throws -> RESPValue {
        try await brpoplpush(from: source, to: dest, timeout: timeout).get()
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
    ///     - type: The type to convert the value to.
    /// - Returns: The element popped from the source list and pushed to the destination.
    ///     If the timeout was reached or `RESPValue` conversion failed, the returned value will be `nil`.
    @inlinable
    public func brpoplpush<Value: RESPValueConvertible>(
        from source: RedisKey,
        to dest: RedisKey,
        timeout: TimeAmount = .seconds(0),
        valueType: Value.Type
    ) async throws -> Value? {
        try await brpoplpush(from: source, to: dest, timeout: timeout, valueType: valueType).get()
    }
}

// MARK: Insert

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
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
    ) async throws -> Int {
        try await linsert(element, into: key, before: pivot).get()
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
    ) async throws -> Int {
        try await linsert(element, into: key, after: pivot).get()
    }
}

// MARK: Head Operations

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension RedisClient {
    /// Removes the first element of a list.
    ///
    /// See [https://redis.io/commands/lpop](https://redis.io/commands/lpop)
    /// - Parameter key: The key of the list to pop from.
    /// - Returns: The element that was popped from the list, or `.null`.
    public func lpop(from key: RedisKey) async throws -> RESPValue {
        try await lpop(from: key).get()
    }

    /// Removes the first element of a list.
    ///
    /// See [https://redis.io/commands/lpop](https://redis.io/commands/lpop)
    /// - Parameters:
    ///     - key: The key of the list to pop from.
    ///     - type: The type to convert the value to.
    /// - Returns: The element that was popped from the list. If the list is empty or the `RESPValue` conversion failed, this value is `nil`.
    @inlinable
    public func lpop<Value: RESPValueConvertible>(from key: RedisKey, as type: Value.Type) async throws -> Value? {
        try await lpop(from: key, as: type).get()
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
    public func lpush<Value: RESPValueConvertible>(_ elements: [Value], into key: RedisKey) async throws -> Int {
        try await lpush(elements, into: key).get()
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
    public func lpush<Value: RESPValueConvertible>(_ elements: Value..., into key: RedisKey) async throws -> Int {
        try await lpush(elements, into: key).get()
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
    public func lpushx<Value: RESPValueConvertible>(_ element: Value, into key: RedisKey) async throws -> Int {
        try await lpushx(element, into: key).get()
    }
}

// MARK: Tail Operations

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension RedisClient {
    /// Removes the last element a list.
    ///
    /// See [https://redis.io/commands/rpop](https://redis.io/commands/rpop)
    /// - Parameter key: The key of the list to pop from.
    /// - Returns: The element that was popped from the list, else `.null`.
    public func rpop(from key: RedisKey) async throws -> RESPValue {
        try await rpop(from: key).get()
    }

    /// Removes the last element a list.
    ///
    /// See [https://redis.io/commands/rpop](https://redis.io/commands/rpop)
    /// - Parameter key: The key of the list to pop from.
    /// - Returns: The element that was popped from the list. If the list is empty or the `RESPValue` conversion fails, this value is `nil`.
    @inlinable
    public func rpop<Value: RESPValueConvertible>(from key: RedisKey, as type: Value.Type) async throws -> Value? {
        try await rpop(from: key, as: type).get()
    }

    /// Pushes all of the provided elements into a list.
    /// - Note: This inserts the elements at the tail of the list; for the head see `lpush(_:into:)`.
    ///
    /// See [https://redis.io/commands/rpush](https://redis.io/commands/rpush)
    ///     - elements: The values to push into the list.
    ///     - key: The key of the list.
    /// - Returns: The length of the list after adding the new elements.
    @inlinable
    public func rpush<Value: RESPValueConvertible>(_ elements: [Value], into key: RedisKey) async throws -> Int {
        try await rpush(elements, into: key).get()
    }

    /// Pushes all of the provided elements into a list.
    /// - Note: This inserts the elements at the tail of the list; for the head see `lpush(_:into:)`.
    ///
    /// See [https://redis.io/commands/rpush](https://redis.io/commands/rpush)
    ///     - elements: The values to push into the list.
    ///     - key: The key of the list.
    /// - Returns: The length of the list after adding the new elements.
    @inlinable
    public func rpush<Value: RESPValueConvertible>(_ elements: Value..., into key: RedisKey) async throws -> Int {
        try await rpush(elements, into: key).get()
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
    public func rpushx<Value: RESPValueConvertible>(_ element: Value, into key: RedisKey) async throws -> Int {
        try await rpushx(element, into: key).get()
    }
}

// MARK: Blocking Pop

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
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
    /// - Returns: The element that was popped from the list, or `.null` if the timeout was reached.
    public func blpop(from key: RedisKey, timeout: TimeAmount = .seconds(0)) async throws -> RESPValue {
        try await blpop(from: key, timeout: timeout).get()
    }

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
    ///     - type: The type to convert the value to.
    ///     - timeout: The max time to wait for a value to use. `0`seconds means to wait indefinitely.
    /// - Returns: The element that was popped from the list. If the timeout was reached or `RESPValue` conversion failed, `nil`.
    @inlinable
    public func blpop<Value: RESPValueConvertible>(
        from key: RedisKey,
        as type: Value.Type,
        timeout: TimeAmount = .seconds(0)
    ) async throws -> Value? {
        try await blpop(from: key, as: type, timeout: timeout).get()
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
    public func blpop(from keys: [RedisKey], timeout: TimeAmount = .seconds(0)) async throws -> (RedisKey, RESPValue)? {
        try await blpop(from: keys, timeout: timeout).get()
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
    ///     - valueType: The type to convert the value to.
    /// - Returns:
    ///     If timeout was reached or the `RESPValue` conversion failed, `nil`.
    ///
    ///     Otherwise, the key of the list the element was removed from and the popped element.
    @inlinable
    public func blpop<Value: RESPValueConvertible>(
        from keys: [RedisKey],
        timeout: TimeAmount = .seconds(0),
        valueType: Value.Type
    ) async throws -> (RedisKey, Value)? {
        try await blpop(from: keys, timeout: timeout, valueType: valueType).get()
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
    public func blpop(from keys: RedisKey..., timeout: TimeAmount = .seconds(0)) async throws -> (RedisKey, RESPValue)? {
        try await blpop(from: keys, timeout: timeout).get()
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
    ///     - valueType: The type to convert the value to.
    /// - Returns:
    ///     If timeout was reached or `RESPValue` conversion failed, `nil`.
    ///
    ///     Otherwise, the key of the list the element was removed from and the popped element.
    @inlinable
    public func blpop<Value: RESPValueConvertible>(
        from keys: RedisKey...,
        timeout: TimeAmount = .seconds(0),
        valueType: Value.Type
    ) async throws -> (RedisKey, Value)? {
        try await blpop(from: keys, timeout: timeout, valueType: valueType).get()
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
    /// - Returns: The element that was popped from the list, or `.null` if the timeout was reached.
    public func brpop(from key: RedisKey, timeout: TimeAmount = .seconds(0)) async throws -> RESPValue {
        try await brpop(from: key, timeout: timeout).get()
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
    ///     - type: The type to convert the value to.
    ///     - timeout: The max time to wait for a value to use. `0`seconds means to wait indefinitely.
    /// - Returns: The element that was popped from the list. If the timeout was reached or the `RESPValue` conversion fails, this value is `nil`.
    @inlinable
    public func brpop<Value: RESPValueConvertible>(
        from key: RedisKey,
        as type: Value.Type,
        timeout: TimeAmount = .seconds(0)
    ) async throws -> Value? {
        try await brpop(from: key, as: type, timeout: timeout).get()
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
    public func brpop(from keys: [RedisKey], timeout: TimeAmount = .seconds(0)) async throws -> (RedisKey, RESPValue)? {
        try await brpop(from: keys, timeout: timeout).get()
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
    ///     If timeout was reached or `RESPValue` conversion failed, `nil`.
    ///
    ///     Otherwise, the key of the list the element was removed from and the popped element.
    @inlinable
    public func brpop<Value: RESPValueConvertible>(
        from keys: [RedisKey],
        timeout: TimeAmount = .seconds(0),
        valueType: Value.Type
    ) async throws -> (RedisKey, Value)? {
        try await brpop(from: keys, timeout: timeout, valueType: valueType).get()
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
    public func brpop(from keys: RedisKey..., timeout: TimeAmount = .seconds(0)) async throws -> (RedisKey, RESPValue)? {
        try await brpop(from: keys, timeout: timeout).get()
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
    ///     If timeout was reached or `RESPValue` conversion failed, `nil`.
    ///
    ///     Otherwise, the key of the list the element was removed from and the popped element.
    @inlinable
    public func brpop<Value: RESPValueConvertible>(
        from keys: RedisKey...,
        timeout: TimeAmount = .seconds(0),
        valueType: Value.Type
    ) async throws -> (RedisKey, Value)? {
        try await brpop(from: keys, timeout: timeout, valueType: valueType).get()
    }
}
