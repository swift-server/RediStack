//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2019 Apple Inc. and the RediStack project authors
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

extension RedisClient {
    /// Gets the length of a list.
    ///
    /// See [https://redis.io/commands/llen](https://redis.io/commands/llen)
    /// - Parameter key: The key of the list.
    /// - Returns: The number of elements in the list.
    public func llen(of key: RedisKey) -> EventLoopFuture<Int> {
        let args = [RESPValue(from: key)]
        return send(command: "LLEN", with: args)
            .tryConverting()
    }

    /// Gets the element from a list stored at the provided index position.
    ///
    /// See [https://redis.io/commands/lindex](https://redis.io/commands/lindex)
    /// - Parameters:
    ///     - index: The 0-based index of the element to get.
    ///     - key: The key of the list.
    /// - Returns: The element stored at index, or `.null` if out of bounds.
    public func lindex(_ index: Int, from key: RedisKey) -> EventLoopFuture<RESPValue> {
        let args: [RESPValue] = [
            .init(from: key),
            .init(bulk: index),
        ]
        return send(command: "LINDEX", with: args)
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
    ) -> EventLoopFuture<Value?> {
        self.lindex(index, from: key)
            .map(Value.init(fromRESP:))
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
            .init(from: key),
            .init(bulk: index),
            value.convertedToRESPValue(),
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
            .init(from: key),
            .init(bulk: count),
            value.convertedToRESPValue(),
        ]
        return send(command: "LREM", with: args)
            .tryConverting()
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
    public func ltrim(_ key: RedisKey, before start: Int, after stop: Int) -> EventLoopFuture<Void> {
        let args: [RESPValue] = [
            .init(from: key),
            .init(bulk: start),
            .init(bulk: stop),
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
    public func ltrim(_ key: RedisKey, keepingIndices range: ClosedRange<Int>) -> EventLoopFuture<Void> {
        self.ltrim(key, before: range.lowerBound, after: range.upperBound)
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
    public func ltrim(_ key: RedisKey, keepingIndices range: PartialRangeFrom<Int>) -> EventLoopFuture<Void> {
        self.ltrim(key, before: range.lowerBound, after: -1)
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
    public func ltrim(_ key: RedisKey, keepingIndices range: PartialRangeUpTo<Int>) -> EventLoopFuture<Void> {
        self.ltrim(key, before: 0, after: range.upperBound - 1)
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
    public func ltrim(_ key: RedisKey, keepingIndices range: PartialRangeThrough<Int>) -> EventLoopFuture<Void> {
        self.ltrim(key, before: 0, after: range.upperBound)
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
    public func ltrim(_ key: RedisKey, keepingIndices range: Range<Int>) -> EventLoopFuture<Void> {
        self.ltrim(key, before: range.lowerBound, after: range.upperBound - 1)
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
    public func lrange(from key: RedisKey, firstIndex: Int, lastIndex: Int) -> EventLoopFuture<[RESPValue]> {
        let args: [RESPValue] = [
            .init(from: key),
            .init(bulk: firstIndex),
            .init(bulk: lastIndex),
        ]
        return send(command: "LRANGE", with: args)
            .tryConverting()
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
    ) -> EventLoopFuture<[Value?]> {
        self.lrange(from: key, firstIndex: firstIndex, lastIndex: lastIndex)
            .map { $0.map(Value.init(fromRESP:)) }
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
    public func lrange(from key: RedisKey, indices range: ClosedRange<Int>) -> EventLoopFuture<[RESPValue]> {
        self.lrange(from: key, firstIndex: range.lowerBound, lastIndex: range.upperBound)
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
    ) -> EventLoopFuture<[Value?]> {
        self.lrange(from: key, indices: range)
            .map { $0.map(Value.init(fromRESP:)) }
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
    public func lrange(from key: RedisKey, indices range: Range<Int>) -> EventLoopFuture<[RESPValue]> {
        self.lrange(from: key, firstIndex: range.lowerBound, lastIndex: range.upperBound - 1)
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
    ) -> EventLoopFuture<[Value?]> {
        self.lrange(from: key, indices: range)
            .map { $0.map(Value.init(fromRESP:)) }
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
    public func lrange(from key: RedisKey, fromIndex index: Int) -> EventLoopFuture<[RESPValue]> {
        self.lrange(from: key, firstIndex: index, lastIndex: -1)
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
    ) -> EventLoopFuture<[Value?]> {
        self.lrange(from: key, fromIndex: index)
            .map { $0.map(Value.init(fromRESP:)) }
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
    public func lrange(from key: RedisKey, throughIndex index: Int) -> EventLoopFuture<[RESPValue]> {
        self.lrange(from: key, firstIndex: 0, lastIndex: index)
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
    ) -> EventLoopFuture<[Value?]> {
        self.lrange(from: key, throughIndex: index)
            .map { $0.map(Value.init(fromRESP:)) }
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
    public func lrange(from key: RedisKey, upToIndex index: Int) -> EventLoopFuture<[RESPValue]> {
        self.lrange(from: key, firstIndex: 0, lastIndex: index - 1)
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
    ) -> EventLoopFuture<[Value?]> {
        self.lrange(from: key, upToIndex: index)
            .map { $0.map(Value.init(fromRESP:)) }
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
    public func rpoplpush(from source: RedisKey, to dest: RedisKey) -> EventLoopFuture<RESPValue> {
        let args: [RESPValue] = [
            .init(from: source),
            .init(from: dest),
        ]
        return send(command: "RPOPLPUSH", with: args)
    }

    /// Pops the last element from a source list and pushes it to a destination list.
    ///
    /// See [https://redis.io/commands/rpoplpush](https://redis.io/commands/rpoplpush)
    /// - Parameters:
    ///     - source: The key of the list to pop from.
    ///     - dest: The key of the list to push to.
    ///     - valueType: Type of the value.
    /// - Returns: The element that was moved. This value is `nil` if the `RESPValue` conversion failed.
    @inlinable
    public func rpoplpush<Value: RESPValueConvertible>(
        from source: RedisKey,
        to dest: RedisKey,
        valueType: Value.Type
    ) -> EventLoopFuture<Value?> {
        self.rpoplpush(from: source, to: dest)
            .map(Value.init(fromRESP:))
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
    ) -> EventLoopFuture<RESPValue> {
        let args: [RESPValue] = [
            .init(from: source),
            .init(from: dest),
            .init(from: timeout.seconds),
        ]
        return send(command: "BRPOPLPUSH", with: args)
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
    ///     - valueType: Type of the value.
    /// - Returns: The element popped from the source list and pushed to the destination.
    ///     If the timeout was reached or `RESPValue` conversion failed, the returned value will be `nil`.
    @inlinable
    public func brpoplpush<Value: RESPValueConvertible>(
        from source: RedisKey,
        to dest: RedisKey,
        timeout: TimeAmount = .seconds(0),
        valueType: Value.Type
    ) -> EventLoopFuture<Value?> {
        self.brpoplpush(from: source, to: dest, timeout: timeout)
            .map(Value.init(fromRESP:))
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
        _linsert(pivotKeyword: "BEFORE", element, key, pivot)
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
        _linsert(pivotKeyword: "AFTER", element, key, pivot)
    }

    @usableFromInline
    func _linsert<Value: RESPValueConvertible>(
        pivotKeyword: String,
        _ element: Value,
        _ key: RedisKey,
        _ pivot: Value
    ) -> EventLoopFuture<Int> {
        let args: [RESPValue] = [
            .init(from: key),
            .init(bulk: pivotKeyword),
            pivot.convertedToRESPValue(),
            element.convertedToRESPValue(),
        ]
        return send(command: "LINSERT", with: args)
            .tryConverting()
    }
}

// MARK: Head Operations

extension RedisClient {
    /// Removes the first element of a list.
    ///
    /// See [https://redis.io/commands/lpop](https://redis.io/commands/lpop)
    /// - Parameter key: The key of the list to pop from.
    /// - Returns: The element that was popped from the list, or `.null`.
    public func lpop(from key: RedisKey) -> EventLoopFuture<RESPValue> {
        let args = [RESPValue(from: key)]
        return send(command: "LPOP", with: args)
    }

    /// Removes the first element of a list.
    ///
    /// See [https://redis.io/commands/lpop](https://redis.io/commands/lpop)
    /// - Parameters:
    ///     - key: The key of the list to pop from.
    ///     - type: The type to convert the value to.
    /// - Returns: The element that was popped from the list. If the list is empty or the `RESPValue` conversion failed, this value is `nil`.
    @inlinable
    public func lpop<Value: RESPValueConvertible>(from key: RedisKey, as type: Value.Type) -> EventLoopFuture<Value?> {
        self.lpop(from: key)
            .map(Value.init(fromRESP:))
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

        var args: [RESPValue] = [.init(from: key)]
        args.append(convertingContentsOf: elements)

        return send(command: "LPUSH", with: args)
            .tryConverting()
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
        self.lpush(elements, into: key)
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
            .init(from: key),
            element.convertedToRESPValue(),
        ]
        return send(command: "LPUSHX", with: args)
            .tryConverting()
    }
}

// MARK: Tail Operations

extension RedisClient {
    /// Removes the last element a list.
    ///
    /// See [https://redis.io/commands/rpop](https://redis.io/commands/rpop)
    /// - Parameter key: The key of the list to pop from.
    /// - Returns: The element that was popped from the list, else `.null`.
    public func rpop(from key: RedisKey) -> EventLoopFuture<RESPValue> {
        let args = [RESPValue(from: key)]
        return send(command: "RPOP", with: args)
    }

    /// Removes the last element a list.
    ///
    /// See [https://redis.io/commands/rpop](https://redis.io/commands/rpop)
    /// - Parameter key: The key of the list to pop from.
    /// - Parameter type: The type of the value.
    /// - Returns: The element that was popped from the list. If the list is empty or the `RESPValue` conversion fails, this value is `nil`.
    @inlinable
    public func rpop<Value: RESPValueConvertible>(from key: RedisKey, as type: Value.Type) -> EventLoopFuture<Value?> {
        self.rpop(from: key)
            .map(Value.init(fromRESP:))
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

        var args: [RESPValue] = [.init(from: key)]
        args.append(convertingContentsOf: elements)

        return send(command: "RPUSH", with: args)
            .tryConverting()
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
        self.rpush(elements, into: key)
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
            .init(from: key),
            element.convertedToRESPValue(),
        ]
        return send(command: "RPUSHX", with: args)
            .tryConverting()
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
    /// - Returns: The element that was popped from the list, or `.null` if the timeout was reached.
    public func blpop(from key: RedisKey, timeout: TimeAmount = .seconds(0)) -> EventLoopFuture<RESPValue> {
        blpop(from: [key], timeout: timeout)
            .map { $0?.1 ?? .null }
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
    ) -> EventLoopFuture<Value?> {
        self.blpop(from: key, timeout: timeout)
            .map(Value.init(fromRESP:))
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
    public func blpop(
        from keys: [RedisKey],
        timeout: TimeAmount = .seconds(0)
    ) -> EventLoopFuture<(RedisKey, RESPValue)?> {
        _bpop(command: "BLPOP", keys, timeout)
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
    ) -> EventLoopFuture<(RedisKey, Value)?> {
        self.blpop(from: keys, timeout: timeout)
            .map {
                guard
                    let result = $0,
                    let value = Value(fromRESP: result.1)
                else { return nil }
                return (result.0, value)
            }
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
    public func blpop(
        from keys: RedisKey...,
        timeout: TimeAmount = .seconds(0)
    ) -> EventLoopFuture<(RedisKey, RESPValue)?> {
        self.blpop(from: keys, timeout: timeout)
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
    ) -> EventLoopFuture<(RedisKey, Value)?> {
        self.blpop(from: keys, timeout: timeout, valueType: valueType)
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
    public func brpop(from key: RedisKey, timeout: TimeAmount = .seconds(0)) -> EventLoopFuture<RESPValue> {
        brpop(from: [key], timeout: timeout)
            .map { $0?.1 ?? .null }
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
    ) -> EventLoopFuture<Value?> {
        self.brpop(from: key, timeout: timeout)
            .map(Value.init(fromRESP:))
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
    public func brpop(
        from keys: [RedisKey],
        timeout: TimeAmount = .seconds(0)
    ) -> EventLoopFuture<(RedisKey, RESPValue)?> {
        _bpop(command: "BRPOP", keys, timeout)
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
    ///     - valueType: Type of the value.
    /// - Returns:
    ///     If timeout was reached or `RESPValue` conversion failed, `nil`.
    ///
    ///     Otherwise, the key of the list the element was removed from and the popped element.
    @inlinable
    public func brpop<Value: RESPValueConvertible>(
        from keys: [RedisKey],
        timeout: TimeAmount = .seconds(0),
        valueType: Value.Type
    ) -> EventLoopFuture<(RedisKey, Value)?> {
        self.brpop(from: keys, timeout: timeout)
            .map {
                guard
                    let result = $0,
                    let value = Value(fromRESP: result.1)
                else { return nil }
                return (result.0, value)
            }
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
    public func brpop(
        from keys: RedisKey...,
        timeout: TimeAmount = .seconds(0)
    ) -> EventLoopFuture<(RedisKey, RESPValue)?> {
        self.brpop(from: keys, timeout: timeout)
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
    ///     - valueType: The type of the value.
    /// - Returns:
    ///     If timeout was reached or `RESPValue` conversion failed, `nil`.
    ///
    ///     Otherwise, the key of the list the element was removed from and the popped element.
    @inlinable
    public func brpop<Value: RESPValueConvertible>(
        from keys: RedisKey...,
        timeout: TimeAmount = .seconds(0),
        valueType: Value.Type
    ) -> EventLoopFuture<(RedisKey, Value)?> {
        self.brpop(from: keys, timeout: timeout, valueType: valueType)
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
                guard let response = $0.array else {
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
