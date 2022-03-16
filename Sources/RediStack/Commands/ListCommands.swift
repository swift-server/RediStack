//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2019-2022 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIO

// MARK: Lists

extension RedisCommand {
    /// [BLPOP](https://redis.io/commands/blpop)
    /// - Warning:
    ///     This will block the connection from completing further commands until an element is available to pop from the list.
    ///
    ///     It is **highly** recommended to set a reasonable `timeout` or to use the non-blocking `lpop` method where possible.
    /// - Parameters:
    ///     - key: The key of the list to pop from.
    ///     - timeout: The max time to wait for a value to use. `0`seconds means to wait indefinitely.
    public static func blpop(from key: RedisKey, timeout: TimeAmount = .seconds(0)) -> RedisCommand<RESPValue?> {
        return ._bpop(keyword: "BLPOP", [key], timeout, { $0?.1 })
    }

    /// [BLPOP](https://redis.io/commands/blpop)
    /// - Warning:
    ///     This will block the connection from completing further commands until an element is available to pop from the list.
    ///
    ///     It is **highly** recommended to set a reasonable `timeout` or to use the non-blocking `lpop` method where possible.
    /// - Parameters:
    ///     - keys: The list of keys to pop from.
    ///     - timeout: The max time to wait for a value to use. `0`seconds means to wait indefinitely.
    public static func blpop(
        from keys: [RedisKey],
        timeout: TimeAmount = .seconds(0)
    ) -> RedisCommand<(RedisKey, RESPValue)?> {
        return ._bpop(keyword: "BLPOP", keys, timeout, { $0 })
    }

    /// [BLPOP](https://redis.io/commands/blpop)
    /// - Warning:
    ///     This will block the connection from completing further commands until an element is available to pop from the list.
    ///
    ///     It is **highly** recommended to set a reasonable `timeout` or to use the non-blocking `lpop` method where possible.
    /// - Parameters:
    ///     - keys: The list of keys to pop from.
    ///     - timeout: The max time to wait for a value to use. `0`seconds means to wait indefinitely.
    public static func blpop(
        from keys: RedisKey...,
        timeout: TimeAmount = .seconds(0)
    ) -> RedisCommand<(RedisKey, RESPValue)?> { .blpop(from: keys, timeout: timeout) }

    /// [BRPOP](https://redis.io/commands/brpop)
    /// - Warning:
    ///     This will block the connection from completing further commands until an element is available to pop from the list.
    ///
    ///     It is **highly** recommended to set a reasonable `timeout` or to use the non-blocking `rpop` method where possible.
    /// - Parameters:
    ///     - key: The key of the list to pop from.
    ///     - timeout: The max time to wait for a value to use. `0`seconds means to wait indefinitely.
    public static func brpop(from key: RedisKey, timeout: TimeAmount = .seconds(0)) -> RedisCommand<RESPValue?> {
        return ._bpop(keyword: "BRPOP", [key], timeout, { $0?.1 })
    }

    /// [BRPOP](https://redis.io/commands/brpop)
    /// - Warning:
    ///     This will block the connection from completing further commands until an element is available to pop from the list.
    ///
    ///     It is **highly** recommended to set a reasonable `timeout` or to use the non-blocking `rpop` method where possible.
    /// - Parameters:
    ///     - key: The key of the list to pop from.
    ///     - timeout: The max time to wait for a value to use. `0`seconds means to wait indefinitely.
    public static func brpop(from keys: [RedisKey], timeout: TimeAmount = .seconds(0)) -> RedisCommand<(RedisKey, RESPValue)?> {
        return ._bpop(keyword: "BRPOP", keys, timeout, { $0 })
    }

    /// [BRPOP](https://redis.io/commands/brpop)
    /// - Warning:
    ///     This will block the connection from completing further commands until an element is available to pop from the list.
    ///
    ///     It is **highly** recommended to set a reasonable `timeout` or to use the non-blocking `rpop` method where possible.
    /// - Parameters:
    ///     - key: The key of the list to pop from.
    ///     - timeout: The max time to wait for a value to use. `0`seconds means to wait indefinitely.
    public static func brpop(
        from keys: RedisKey...,
        timeout: TimeAmount = .seconds(0)
    ) -> RedisCommand<(RedisKey, RESPValue)?> { .brpop(from: keys, timeout: timeout) }

    /// [BRPOPLPUSH](https://redis.io/commands/brpoplpush)
    /// - Warning:
    ///     This will block the connection from completing further commands until an element is available to pop from the source list.
    ///
    ///     It is **highly** recommended to set a reasonable `timeout` or to use the non-blocking `rpoplpush` method where possible.
    /// - Parameters:
    ///     - source: The key of the list to pop from.
    ///     - dest: The key of the list to push to.
    ///     - timeout: The max time to wait for a value to use. `0` seconds means to wait indefinitely.
    public static func brpoplpush(
        from source: RedisKey,
        to dest: RedisKey,
        timeout: TimeAmount = .seconds(0)
    ) -> RedisCommand<RESPValue?> {
        let args: [RESPValue] = [
            .init(from: source),
            .init(from: dest),
            .init(from: timeout.seconds)
        ]
        return .init(keyword: "BRPOPLPUSH", arguments: args)
    }

    /// [LINDEX](https://redis.io/commands/lindex)
    /// - Parameters:
    ///     - index: The 0-based index of the element to get.
    ///     - key: The key of the list.
    public static func lindex(_ index: Int, from key: RedisKey) -> RedisCommand<RESPValue?> {
        let args: [RESPValue] = [
            .init(from: key),
            .init(bulk: index)
        ]
        return .init(keyword: "LINDEX", arguments: args) { try? $0.map() }
    }

    /// [LINSERT](https://redis.io/commands/linsert)
    /// - Parameters:
    ///     - element: The value to insert into the list.
    ///     - key: The key of the list.
    ///     - pivot: The value of the element to insert before.
    @inlinable
    public static func linsert<Value: RESPValueConvertible>(
        _ element: Value,
        into key: RedisKey,
        before pivot: Value
    ) -> RedisCommand<Int> { ._linsert(pivotKeyword: "BEFORE", element, key, pivot) }

    /// [LINSERT](https://redis.io/commands/linsert)
    /// - Parameters:
    ///     - element: The value to insert into the list.
    ///     - key: The key of the list.
    ///     - pivot: The value of the element to insert after.
    @inlinable
    public static func linsert<Value: RESPValueConvertible>(
        _ element: Value,
        into key: RedisKey,
        after pivot: Value
    ) -> RedisCommand<Int> { ._linsert(pivotKeyword: "AFTER", element, key, pivot) }

    /// [LLEN](https://redis.io/commands/llen)
    /// - Parameter key: The key of the list.
    public static func llen(of key: RedisKey) -> RedisCommand<Int> {
        let args = [RESPValue(from: key)]
        return .init(keyword: "LLEN", arguments: args)
    }

    /// [LPOP](https://redis.io/commands/lpop)
    /// - Parameter key: The key of the list to pop from.
    public static func lpop(from key: RedisKey) -> RedisCommand<RESPValue?> {
        let args = [RESPValue(from: key)]
        return .init(keyword: "LPOP", arguments: args) { try? $0.map() }
    }

    /// [LPUSH](https://redis.io/commands/lpush)
    /// - Note: This inserts the elements at the head of the list; for the tail see `rpush(_:into:)`.
    /// - Parameters:
    ///     - elements: The values to push into the list.
    ///     - key: The key of the list.
    @inlinable
    public static func lpush<Value: RESPValueConvertible>(_ elements: [Value], into key: RedisKey) -> RedisCommand<Int> {
        assert(elements.count > 0, "at least 1 element should be provided")
        
        var args = [RESPValue(from: key)]
        args.append(convertingContentsOf: elements)
        
        return .init(keyword: "LPUSH", arguments: args)
    }

    /// [LPUSH](https://redis.io/commands/lpush)
    /// - Note: This inserts the elements at the head of the list; for the tail see `rpush(_:into:)`.
    /// - Parameters:
    ///     - elements: The values to push into the list.
    ///     - key: The key of the list.
    @inlinable
    public static func lpush<Value: RESPValueConvertible>(
        _ elements: Value...,
        into key: RedisKey
    ) -> RedisCommand<Int> { .lpush(elements, into: key) }

    /// [LPUSHX](https://redis.io/commands/lpushx)
    /// - Note: This inserts the element at the head of the list, for the tail see ``rpushx(_:into:)``.
    /// - Parameters:
    ///     - element: The value to try and push into the list.
    ///     - key: The key of the list.
    @inlinable
    public static func lpushx<Value: RESPValueConvertible>(_ element: Value, into key: RedisKey) -> RedisCommand<Int> {
        let args: [RESPValue] = [
            .init(from: key),
            element.convertedToRESPValue()
        ]
        return .init(keyword: "LPUSHX", arguments: args)
    }

    /// [LRANGE](https://redis.io/commands/lrange)
    /// - Parameters:
    ///     - key: The key of the List.
    ///     - firstIndex: The inclusive index of the first element to include in the range of elements returned.
    ///     - lastIndex: The inclusive index of the last element to include in the range of elements returned.
    public static func lrange(from key: RedisKey, firstIndex: Int, lastIndex: Int) -> RedisCommand<[RESPValue]> {
        let args: [RESPValue] = [
            .init(from: key),
            .init(bulk: firstIndex),
            .init(bulk: lastIndex)
        ]
        return .init(keyword: "LRANGE", arguments: args)
    }

    /// [LRANGE](https://redis.io/commands/lrange)
    ///
    /// Example usage:
    /// ```swift
    /// // elements at indices 4-7
    /// client.send(.lrange(from: "myList", indices: 4...7))
    ///
    /// // last 4 elements
    /// client.send(.lrange(from: "myList", indices: (-4)...(-1)))
    ///
    /// // first and last 4 elements
    /// client.send(.lrange(from: "myList", indices: (-4)...3))
    ///
    /// // first element, and the last 4
    /// client.send(.lrange(from: "myList", indices: (-4)...0))
    /// ```
    /// - Precondition: A `ClosedRange` cannot be created where `upperBound` is less than `lowerBound`; so while Redis may support `0...-1`,
    ///     `ClosedRange` will trigger a precondition failure.
    ///
    ///     If you need such a range, use ``lrange(from:firstIndex:lastIndex:)`` instead.
    /// - Parameters:
    ///     - key: The key of the List to return elements from.
    ///     - range: The range of inclusive indices of elements to get.
    public static func lrange(from key: RedisKey, indices range: ClosedRange<Int>) -> RedisCommand<[RESPValue]> {
        return .lrange(from: key, firstIndex: range.lowerBound, lastIndex: range.upperBound)
    }

    /// [LRANGE](https://redis.io/commands/lrange)
    ///
    /// Example usage:
    /// ```swift
    /// // elements at indicies 4-7
    /// client.send(.lrange(from: "myList", indices: 4..<8))
    ///
    /// // last 4 elements
    /// client.send(.lrange(from: "myList", indices: (-4)..<0))
    ///
    /// // first and last 4 elements
    /// client.send(.lrange(from: "myList", indices: (-4)..<4))
    ///
    /// // first element and the last 4
    /// client.send(.lrange(from: "myList", indices: (-4)..<1))
    /// ```
    /// - Precondition: A `Range` cannot be created where `upperBound` is less than `lowerBound`; so while Redis may support `0..<(-1)`,
    ///     `Range` will trigger a precondition failure.
    ///
    ///     If you need such a range, use ``lrange(from:firstIndex:lastIndex:)`` instead.
    /// - Parameters:
    ///     - key: The key of the List to return elements from.
    ///     - range: The range of indices (inclusive lower, exclusive upper) elements to get.
    public static func lrange(from key: RedisKey, indices range: Range<Int>) -> RedisCommand<[RESPValue]> {
        return .lrange(from: key, firstIndex: range.lowerBound, lastIndex: range.upperBound - 1)
    }

    /// [LRANGE](https://redis.io/commands/lrange)
    ///
    /// Example usage:
    /// ```swift
    /// // all except first 2 elements
    /// client.send(.lrange(from: "myList", fromIndex: 2))
    ///
    /// // last 4 elements
    /// client.send(.lrange(from: "myList", fromIndex: -4))
    /// ```
    /// - Parameters:
    ///     - key: The key of the List to return elements from.
    ///     - index: The index of the first element that will be in the returned values.
    public static func lrange(from key: RedisKey, fromIndex index: Int) -> RedisCommand<[RESPValue]> {
        return .lrange(from: key, firstIndex: index, lastIndex: -1)
    }

    /// [LRANGE](https://redis.io/commands/lrange)
    ///
    /// Example usage:
    /// ```swift
    /// // first 3 elements
    /// client.send(.lrange(from: "myList", throughIndex: 2))
    ///
    /// // all except last 3 elements
    /// client.send(.lrange(from: "myList", throughIndex: -4))
    /// ```
    /// - Parameters:
    ///     - key: The key of the List to return elements from.
    ///     - index: The index of the last element that will be in the returned values.
    public static func lrange(from key: RedisKey, throughIndex index: Int) -> RedisCommand<[RESPValue]> {
        return .lrange(from: key, firstIndex: 0, lastIndex: index)
    }

    /// [LRANGE](https://redis.io/commands/lrange)
    ///
    /// Example usage:
    /// ```swift
    /// // first 3 elements
    /// client.send(.lrange(from: "myList", upToIndex: 3))
    ///
    /// // all except last 3 elements
    /// client.send(.lrange(from: "myList", upToIndex: -3))
    /// ```
    /// - Parameters:
    ///     - key: The key of the List to return elements from.
    ///     - index: The index of the element to not include in the returned values.
    public static func lrange(from key: RedisKey, upToIndex index: Int) -> RedisCommand<[RESPValue]> {
        return .lrange(from: key, firstIndex: 0, lastIndex: index - 1)
    }

    /// [LREM](https://redis.io/commands/lrem)
    /// - Parameters:
    ///     - value: The value to delete from the list.
    ///     - key: The key of the list to remove from.
    ///     - count: The max number of elements to remove matching the value. See Redis' documentation for more info.
    @inlinable
    public static func lrem<Value: RESPValueConvertible>(
        _ value: Value,
        from key: RedisKey,
        count: Int = 0
    ) -> RedisCommand<Int> {
        let args: [RESPValue] = [
            .init(from: key),
            .init(bulk: count),
            value.convertedToRESPValue()
        ]
        return .init(keyword: "LREM", arguments: args)
    }

    /// [LSET](https://redis.io/commands/lset)
    /// - Parameters:
    ///     - index: The 0-based index of the element to set.
    ///     - value: The new value the element should be.
    ///     - key: The key of the list to update.
    @inlinable
    public static func lset<Value: RESPValueConvertible>(
        index: Int,
        to value: Value,
        in key: RedisKey
    ) -> RedisCommand<Void> {
        let args: [RESPValue] = [
            .init(from: key),
            .init(bulk: index),
            value.convertedToRESPValue()
        ]
        return .init(keyword: "LSET", arguments: args)
    }

    /// [LTRIM](https://redis.io/commands/ltrim)
    /// - Parameters:
    ///     - key: The key of the List to trim.
    ///     - start: The index of the first element to keep.
    ///     - stop: The index of the last element to keep.
    @inlinable
    public static func ltrim(_ key: RedisKey, before start: Int, after stop: Int) -> RedisCommand<Void> {
        let args: [RESPValue] = [
            .init(from: key),
            .init(bulk: start),
            .init(bulk: stop)
        ]
        return .init(keyword: "LTRIM", arguments: args)
    }
    
    /// [LTRIM](https://redis.io/commands/ltrim)
    ///
    /// Example usage:
    /// ```swift
    /// // keep elements at indices 4-7
    /// client.send(.ltrim("myList", keepingIndices: 3...6))
    ///
    /// // keep last 4-7 elements
    /// client.send(.ltrim("myList", keepingIndices: (-7)...(-4)))
    ///
    /// // keep first element and last 4
    /// client.send(.ltrim("myList", keepingIndices: (-4)...3))
    /// ```
    /// - Precondition: A `ClosedRange` cannot be created where `upperBound` is less than `lowerBound`; so while Redis may support `0...-1`,
    ///     `ClosedRange` will trigger a precondition failure.
    ///
    ///     If you need such a range, use ``ltrim(_:before:after:)`` instead.
    /// - Parameters:
    ///     - key: The key of the List to trim.
    ///     - range: The range of indices that should be kept in the List.
    public static func ltrim(_ key: RedisKey, keepingIndices range: ClosedRange<Int>) -> RedisCommand<Void> {
        return .ltrim(key, before: range.lowerBound, after: range.upperBound)
    }
    
    /// [LTRIM](https://redis.io/commands/ltrim)
    ///
    /// Example usage:
    /// ```swift
    /// // keep all but the first 3 elements
    /// client.send(.ltrim("myList", keepingIndices: 3...))
    ///
    /// // keep last 4 elements
    /// client.send(.ltrim("myList", keepingIndices: (-4)...))
    /// ```
    /// - Parameters:
    ///     - key: The key of the List to trim.
    ///     - range: The range of indices that should be kept in the List.
    public static func ltrim(_ key: RedisKey, keepingIndices range: PartialRangeFrom<Int>) -> RedisCommand<Void> {
        return self.ltrim(key, before: range.lowerBound, after: -1)
    }

    /// [LTRIM](https://redis.io/commands/ltrim)
    ///
    /// Example usage:
    /// ```swift
    /// // keep first 3 elements
    /// client.send(.ltrim("myList", keepingIndices: ..<3))
    ///
    /// // keep all but the last 4 elements
    /// client.send(.ltrim("myList", keepingIndices: ..<(-4)))
    /// ```
    /// - Parameters:
    ///     - key: The key of the List to trim.
    ///     - range: The range of indices that should be kept in the List.
    public static func ltrim(_ key: RedisKey, keepingIndices range: PartialRangeUpTo<Int>) -> RedisCommand<Void> {
        return self.ltrim(key, before: 0, after: range.upperBound - 1)
    }

    /// [LTRIM](https://redis.io/commands/ltrim)
    ///
    /// Example usage:
    /// ```swift
    /// // keep first 4 elements
    /// client.send(.ltrim("myList", keepingIndices: ...3))
    ///
    /// // keep all but the last 3 elements
    /// client.send(.ltrim("myList", keepingIndices: ...(-4)))
    /// ```
    /// - Parameters:
    ///     - key: The key of the List to trim.
    ///     - range: The range of indices that should be kept in the List.
    public static func ltrim(_ key: RedisKey, keepingIndices range: PartialRangeThrough<Int>) -> RedisCommand<Void> {
        return self.ltrim(key, before: 0, after: range.upperBound)
    }

    /// [LTRIM](https://redis.io/commands/ltrim)
    ///
    /// Example usage:
    /// ```swift
    /// // keep first 4 elements
    /// client.send(.ltrim("myList", keepingIndices: 0..<4))
    ///
    /// // keep all but the last 3 elements
    /// client.send(.ltrim("myList", keepingIndices: 0..<(-3)))
    /// ```
    /// - Parameters:
    ///     - key: The key of the List to trim.
    ///     - range: The range of indices that should be kept in the List.
    public static func ltrim(_ key: RedisKey, keepingIndices range: Range<Int>) -> RedisCommand<Void> {
        return self.ltrim(key, before: range.lowerBound, after: range.upperBound - 1)
    }

    /// [RPOP](https://redis.io/commands/rpop)
    /// - Parameter key: The key of the list to pop from.
    public static func rpop(from key: RedisKey) -> RedisCommand<RESPValue?> {
        let args = [RESPValue(from: key)]
        return .init(keyword: "RPOP", arguments: args) { try? $0.map() }
    }

    /// [RPOPLPUSH](https://redis.io/commands/rpoplpush)
    /// - Parameters:
    ///     - source: The key of the list to pop from.
    ///     - dest: The key of the list to push to.
    public static func rpoplpush(from source: RedisKey, to dest: RedisKey) -> RedisCommand<RESPValue?> {
        let args: [RESPValue] = [
            .init(from: source),
            .init(from: dest)
        ]
        return .init(keyword: "RPOPLPUSH", arguments: args)
    }

    /// [RPUSH](https://redis.io/commands/rpush)
    /// - Note: This inserts the elements at the tail of the list; for the head see `lpush(_:into:)`.
    /// - Parameters:
    ///     - elements: The values to push into the list.
    ///     - key: The key of the list.
    @inlinable
    public static func rpush<Value: RESPValueConvertible>(_ elements: [Value], into key: RedisKey) -> RedisCommand<Int> {
        assert(elements.count > 0, "at least 1 element should be provided")
    
        var args = [RESPValue(from: key)]
        args.append(convertingContentsOf: elements)
        
        return .init(keyword: "RPUSH", arguments: args)
    }

    /// [RPUSH](https://redis.io/commands/rpush)
    /// - Note: This inserts the elements at the tail of the list; for the head see `lpush(_:into:)`.
    /// - Parameters:
    ///     - elements: The values to push into the list.
    ///     - key: The key of the list.
    @inlinable
    public static func rpush<Value: RESPValueConvertible>(_ elements: Value..., into key: RedisKey) -> RedisCommand<Int> {
        return .rpush(elements, into: key)
    }

    /// [RPUSHX](https://redis.io/commands/rpushx)
    /// - Note: This inserts the element at the tail of the list; for the head see ``lpushx(_:into:)``.
    /// - Parameters:
    ///     - element: The value to try and push into the list.
    ///     - key: The key of the list.
    @inlinable
    public static func rpushx<Value: RESPValueConvertible>(_ element: Value, into key: RedisKey) -> RedisCommand<Int> {
        let args: [RESPValue] = [
            .init(from: key),
            element.convertedToRESPValue()
        ]
        return .init(keyword: "RPUSHX", arguments: args)
    }
}

// MARK: - Shared implementations
extension RedisCommand {
    fileprivate static func _bpop<ResultType>(
        keyword: String,
        _ keys: [RedisKey],
        _ timeout: TimeAmount,
        _ transform: @escaping ((RedisKey, RESPValue)?) throws -> ResultType?
    ) -> RedisCommand<ResultType?> {
        var args = keys.map(RESPValue.init(from:))
        args.append(.init(bulk: timeout.seconds))
        
        return .init(keyword: keyword, arguments: args) { value in
            guard !value.isNull else { return nil }

            let response = try value.map(to: [RESPValue].self)
            assert(response.count == 2, "unexpected response size returned: \(response.count)")

            let key = try response[0].map(to: String.self)
            let initialResult = (RedisKey(key), response[1])

            return try transform(initialResult)
        }
    }

    @usableFromInline
    internal static func _linsert<Value: RESPValueConvertible>(
        pivotKeyword: String,
        _ element: Value,
        _ key: RedisKey,
        _ pivot: Value
    ) -> RedisCommand<Int> {
        let args: [RESPValue] = [
            .init(from: key),
            .init(bulk: pivotKeyword),
            pivot.convertedToRESPValue(),
            element.convertedToRESPValue()
        ]
        return .init(keyword: "LINSERT", arguments: args)
    }
}
