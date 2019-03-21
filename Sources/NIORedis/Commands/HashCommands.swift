import NIO

extension RedisCommandExecutor {
    /// Sets the hash field stored at the provided key with the value specified.
    ///
    /// See [https://redis.io/commands/hset](https://redis.io/commands/hset)
    /// - Returns: `true` if the hash was created, `false` if it was updated.
    @inlinable
    public func hset(_ key: String, field: String, to value: String) -> EventLoopFuture<Bool> {
        return send(command: "HSET", with: [key, field, value])
            .mapFromRESP(to: Int.self)
            .map { return $0 == 1 }
    }

    /// Sets the specified fields to the values provided, overwriting existing values.
    ///
    /// See [https://redis.io/commands/hmset](https://redis.io/commands/hmset)
    @inlinable
    public func hmset(_ key: String, to fields: [String: String]) -> EventLoopFuture<Void> {
        assert(fields.count > 0, "At least 1 key-value pair should be specified")

        let args: [RESPValueConvertible] = fields.reduce(into: [], { (result, element) in
            result.append(element.key)
            result.append(element.value)
        })
        
        return send(command: "HMSET", with: [key] + args)
            .map { _ in () }
    }

    /// Sets the specified hash field to the value provided only if the field does not exist.
    ///
    /// See [https://redis.io/commands/hsetnx](https://redis.io/commands/hsetnx)
    /// - Returns: The success of setting the field's value.
    @inlinable
    public func hsetnx(_ key: String, field: String, to value: String) -> EventLoopFuture<Bool> {
        return send(command: "HSETNX", with: [key, field, value])
            .mapFromRESP(to: Int.self)
            .map { return $0 == 1 }
    }

    /// Gets the value stored in the hash field at the key provided.
    ///
    /// See [https://redis.io/commands/hget](https://redis.io/commands/hget)
    @inlinable
    public func hget(_ key: String, field: String) -> EventLoopFuture<String?> {
        return send(command: "HGET", with: [key, field])
            .map { return String($0) }
    }

    /// Returns the values stored in the fields specified at the key provided.
    ///
    /// See [https://redis.io/commands/hmget](https://redis.io/commands/hmget)
    /// - Returns: A list of values in the same order as the `fields` argument.
    @inlinable
    public func hmget(_ key: String, fields: [String]) -> EventLoopFuture<[String?]> {
        assert(fields.count > 0, "At least 1 field should be specified")

        return send(command: "HMGET", with: [key] + fields)
            .mapFromRESP(to: [RESPValue].self)
            .map { return $0.map(String.init) }
    }

    /// Returns all the fields and values stored at the provided key.
    ///
    /// See [https://redis.io/commands/hgetall](https://redis.io/commands/hgetall)
    /// - Returns: A key-value pair list of fields and their values.
    @inlinable
    public func hgetall(from key: String) -> EventLoopFuture<[String: String]> {
        return send(command: "HGETALL", with: [key])
            .mapFromRESP(to: [String].self)
            .map(Self.mapHashResponseToDictionary)
    }

    /// Removes the specified fields from the hash stored at the key provided.
    ///
    /// See [https://redis.io/commands/hdel](https://redis.io/commands/hdel)
    /// - Returns: The number of fields that were deleted.
    @inlinable
    public func hdel(_ key: String, fields: [String]) -> EventLoopFuture<Int> {
        assert(fields.count > 0, "At least 1 field should be specified")

        return send(command: "HDEL", with: [key] + fields)
            .mapFromRESP()
    }

    /// Checks if the provided key and field exist.
    ///
    /// See [https://redis.io/commands/hexists](https://redis.io/commands/hexists)
    @inlinable
    public func hexists(_ key: String, field: String) -> EventLoopFuture<Bool> {
        return send(command: "HEXISTS", with: [key, field])
            .mapFromRESP(to: Int.self)
            .map { return $0 == 1 }
    }

    /// Returns the number of fields contained in the hash stored at the key provided.
    ///
    /// See [https://redis.io/commands/hlen](https://redis.io/commands/hlen)
    /// - Returns: The number of fields in the hash, or 0 if the key doesn't exist.
    @inlinable
    public func hlen(of key: String) -> EventLoopFuture<Int> {
        return send(command: "HLEN", with: [key])
            .mapFromRESP()
    }

    /// Returns hash field's value length as a string, stored at the provided key.
    ///
    /// See [https://redis.io/commands/hstrlen](https://redis.io/commands/hstrlen)
    @inlinable
    public func hstrlen(of key: String, field: String) -> EventLoopFuture<Int> {
        return send(command: "HSTRLEN", with: [key, field])
            .mapFromRESP()
    }

    /// Returns all field names in the hash stored at the key provided.
    ///
    /// See [https://redis.io/commands/hkeys](https://redis.io/commands/hkeys)
    /// - Returns: An array of field names, or an empty array.
    @inlinable
    public func hkeys(storedAt key: String) -> EventLoopFuture<[String]> {
        return send(command: "HKEYS", with: [key])
            .mapFromRESP()
    }

    /// Returns all of the field values stored in hash at the key provided.
    ///
    /// See [https://redis.io/commands/hvals](https://redis.io/commands/hvals)
    @inlinable
    public func hvals(storedAt key: String) -> EventLoopFuture<[String]> {
        return send(command: "HVALS", with: [key])
            .mapFromRESP()
    }

    /// Increments the field value stored at the key provided, and returns the new value.
    ///
    /// See [https://redis.io/commands/hincrby](https://redis.io/commands/hincrby)
    @inlinable
    public func hincrby(_ key: String, field: String, by amount: Int) -> EventLoopFuture<Int> {
        return send(command: "HINCRBY", with: [key, field, amount])
            .mapFromRESP()
    }

    /// Increments the field value stored at the key provided, and returns the new value.
    ///
    /// See [https://redis.io/commands/hincrbyfloat](https://redis.io/commands/hincrbyfloat)
    @inlinable
    public func hincrbyfloat<T: BinaryFloatingPoint>(_ key: String, field: String, by amount: T) -> EventLoopFuture<T>
        where T: RESPValueConvertible
    {
        return send(command: "HINCRBYFLOAT", with: [key, field, amount])
            .mapFromRESP()
    }

    /// Incrementally iterates over all fields in the hash stored at the key provided.
    ///
    /// [https://redis.io/commands/scan](https://redis.io/commands/scan)
    /// - Parameters:
    ///     - key: The key of the hash.
    ///     - atPosition: The position to start the scan from.
    ///     - count: The number of elements to advance by. Redis default is 10.
    ///     - matching: A glob-style pattern to filter values to be selected from the result set.
    /// - Returns: A cursor position for additional invocations with a limited collection of values stored at the keys.
    @inlinable
    public func hscan(
        _ key: String,
        atPosition pos: Int = 0,
        count: Int? = nil,
        matching match: String? = nil) -> EventLoopFuture<(Int, [String: String])>
    {
        return _scan(command: "HSCAN", resultType: [String].self, key, pos, count, match)
            .map {
                let values = Self.mapHashResponseToDictionary($0.1)
                return ($0.0, values)
            }
    }
}

extension RedisCommandExecutor {
    @inline(__always)
    @usableFromInline
    static func mapHashResponseToDictionary(_ values: [String]) -> [String: String] {
        guard values.count > 0 else { return [:] }

        var result: [String: String] = [:]

        var index = 0
        repeat {
            let field = values[index]
            let value = values[index + 1]
            result[field] = value
            index += 2
        } while (index < values.count)

        return result
    }
}
