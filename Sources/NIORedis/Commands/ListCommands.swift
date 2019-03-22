import NIO

extension RedisCommandExecutor {
    /// Returns the length of the list stored at the key provided.
    ///
    /// See [https://redis.io/commands/llen](https://redis.io/commands/llen)
    @inlinable
    public func llen(of key: String) -> EventLoopFuture<Int> {
        return send(command: "LLEN", with: [key])
            .mapFromRESP()
    }

    /// Returns the element at the specified index stored at the key provided.
    ///
    /// See [https://redis.io/commands/llen](https://redis.io/commands/llen)
    @inlinable
    public func lindex(_ key: String, index: Int) -> EventLoopFuture<RESPValue> {
        return send(command: "LINDEX", with: [key, index])
            .flatMapThrowing { response in
                guard response.isNull else { return response }
                throw RedisError(identifier: #function, reason: "Index out of bounds.")
            }
    }

    /// Sets the value at the specified index stored at the key provided.
    ///
    /// See [https://redis.io/commands/lset](https://redis.io/commands/lset)
    @inlinable
    public func lset(_ key: String, index: Int, to value: RESPValueConvertible) -> EventLoopFuture<Void> {
        return send(command: "LSET", with: [key, index, value])
            .map { _ in () }
    }

    /// Removes elements from the list matching the value provided, up to the count specified.
    ///
    /// See [https://redis.io/commands/lrem](https://redis.io/commands/lrem)
    /// - Returns: The number of elements removed.
    @inlinable
    public func lrem(_ value: RESPValueConvertible, from key: String, count: Int) -> EventLoopFuture<Int> {
        return send(command: "LREM", with: [key, count, value])
            .mapFromRESP()
    }

    /// Trims the list stored at the key provided to contain elements within the bounds of indexes specified.
    ///
    /// See [https://redis.io/commands/ltrim](https://redis.io/commands/ltrim)
    @inlinable
    public func ltrim(_ key: String, startIndex start: Int, endIndex end: Int) -> EventLoopFuture<Void> {
        return send(command: "LTRIM", with: [key, start, end])
            .map { _ in () }
    }

    /// Returns the elements within the range bounds provided.
    ///
    /// See [https://redis.io/commands/ltrim](https://redis.io/commands/ltrim)
    @inlinable
    public func lrange(of key: String, startIndex start: Int, endIndex end: Int) -> EventLoopFuture<[RESPValue]> {
        return send(command: "LRANGE", with: [key, start, end])
            .mapFromRESP()
    }

    /// Pops the last element from the source list and pushes it to the destination list.
    ///
    /// See [https://redis.io/commands/rpoplpush](https://redis.io/commands/rpoplpush)
    /// - Returns: The element that was moved.
    @inlinable
    public func rpoplpush(from source: String, to dest: String) -> EventLoopFuture<RESPValue> {
        return send(command: "RPOPLPUSH", with: [source, dest])
    }
}

// MARK: Insert

extension RedisCommandExecutor {
    /// Inserts the value before the first element matching the pivot value provided.
    ///
    /// See [https://redis.io/commands/linsert](https://redis.io/commands/linsert)
    /// - Returns: The size of the list after the insert, or -1 if an element matching the pivot value was not found.
    @inlinable
    public func linsert<T: RESPValueConvertible>(
        _ value: T,
        into key: String,
        before pivot: T) -> EventLoopFuture<Int>
    {
        return _linsert(pivotKeyword: "BEFORE", value, key, pivot)
    }

    /// Inserts the value after the first element matching the pivot value provided.
    ///
    /// See [https://redis.io/commands/linsert](https://redis.io/commands/linsert)
    /// - Returns: The size of the list after the insert, or -1 if an element matching the pivot value was not found.
    @inlinable
    public func linsert<T: RESPValueConvertible>(
        _ value: T,
        into key: String,
        after pivot: T) -> EventLoopFuture<Int>
    {
        return _linsert(pivotKeyword: "AFTER", value, key, pivot)
    }

    @inline(__always)
    @usableFromInline
    func _linsert(pivotKeyword: StaticString, _ value: RESPValueConvertible, _ key: String, _ pivot: RESPValueConvertible) -> EventLoopFuture<Int> {
        return send(command: "LINSERT", with: [key, pivotKeyword.description, pivot, value])
            .mapFromRESP()
    }
}

// MARK: Head Operations

extension RedisCommandExecutor {
    /// Removes the first element in the list and returns it.
    ///
    /// See [https://redis.io/commands/lpop](https://redis.io/commands/lpop)
    @inlinable
    public func lpop(from key: String) -> EventLoopFuture<RESPValue?> {
        return send(command: "LPOP", with: [key])
            .mapFromRESP()
    }

    /// Inserts all values provided into the list stored at the key specified.
    /// - Note: This inserts the values at the head of the list, for the tail see `rpush(_:to:)`.
    ///
    /// See [https://redis.io/commands/lpush](https://redis.io/commands/lpush)
    /// - Returns: The length of the list after adding the new elements.
    @inlinable
    public func lpush(_ values: [RESPValueConvertible], to key: String) -> EventLoopFuture<Int> {
        return send(command: "LPUSH", with: [key] + values)
            .mapFromRESP()
    }

    /// Inserts the value at the head of the list only if the key exists and holds a list.
    /// - Note: This inserts the values at the head of the list, for the tail see `rpushx(_:to:)`.
    ///
    /// See [https://redis.io/commands/lpushx](https://redis.io/commands/lpushx)
    /// - Returns: The length of the list after adding the new elements.
    @inlinable
    public func lpushx(_ value: RESPValueConvertible, to key: String) -> EventLoopFuture<Int> {
        return send(command: "LPUSHX", with: [key, value])
            .mapFromRESP()
    }
}

// MARK: Tail Operations

extension RedisCommandExecutor {
    /// Removes the last element in the list and returns it.
    ///
    /// See [https://redis.io/commands/rpop](https://redis.io/commands/rpop)
    @inlinable
    public func rpop(from key: String) -> EventLoopFuture<RESPValue?> {
        return send(command: "RPOP", with: [key])
            .mapFromRESP()
    }

    /// Inserts all values provided into the list stored at the key specified.
    /// - Note: This inserts the values at the tail of the list, for the head see `lpush(_:to:)`.
    ///
    /// See [https://redis.io/commands/rpush](https://redis.io/commands/rpush)
    /// - Returns: The size of the list after adding the new elements.
    @inlinable
    public func rpush(_ values: [RESPValueConvertible], to key: String) -> EventLoopFuture<Int> {
        return send(command: "RPUSH", with: [key] + values)
            .mapFromRESP()
    }

    /// Inserts the value at the head of the list only if the key exists and holds a list.
    /// - Note: This inserts the values at the tail of the list, for the head see `lpushx(_:to:)`.
    ///
    /// See [https://redis.io/commands/rpushx](https://redis.io/commands/rpushx)
    /// - Returns: The length of the list after adding the new elements.
    @inlinable
    public func rpushx(_ value: RESPValueConvertible, to key: String) -> EventLoopFuture<Int> {
        return send(command: "RPUSHX", with: [key, value])
            .mapFromRESP()
    }
}
