import Foundation
import NIO

extension RedisCommandExecutor {
    /// Echos the provided message through the Redis instance.
    ///
    /// See [https://redis.io/commands/echo](https://redis.io/commands/echo)
    /// - Parameter message: The message to echo.
    /// - Returns: The message sent with the command.
    public func echo(_ message: String) -> EventLoopFuture<String> {
        return send(command: "ECHO", with: [message])
            .mapFromRESP()
    }

    /// Pings the server, which will respond with a message.
    ///
    /// See [https://redis.io/commands/ping](https://redis.io/commands/ping)
    /// - Parameter with: The optional message that the server should respond with.
    /// - Returns: The provided message or Redis' default response of `"PONG"`.
    public func ping(with message: String? = nil) -> EventLoopFuture<String> {
        let arg = message != nil ? [message] : []
        return send(command: "PING", with: arg)
            .mapFromRESP()
    }

    /// Request for authentication in a password-protected Redis server.
    ///
    /// [https://redis.io/commands/auth](https://redis.io/commands/auth)
    public func authorize(with password: String) -> EventLoopFuture<Void> {
        return send(command: "AUTH", with: [password])
            .map { _ in return () }
    }

    /// Select the Redis logical database having the specified zero-based numeric index.
    /// New connections always use the database `0`.
    ///
    /// [https://redis.io/commands/select](https://redis.io/commands/select)
    public func select(database id: Int) -> EventLoopFuture<Void> {
        return send(command: "SELECT", with: [id.description])
            .map { _ in return () }
    }

    /// Swaps the data of two Redis database by their index ID.
    ///
    /// See [https://redis.io/commands/swapdb](https://redis.io/commands/swapdb)
    /// - Parameters:
    ///     - firstIndex: The index of the first database.
    ///     - secondIndex: The index of the second database.
    /// - Returns: `true` if the swap was successful.
    public func swapdb(firstIndex: Int, secondIndex: Int) -> EventLoopFuture<Bool> {
        return send(command: "SWAPDB", with: [firstIndex, secondIndex])
            .mapFromRESP(to: String.self)
            .map { return $0 == "OK" }
    }
}

extension RedisCommandExecutor {
    /// Removes the specified keys. A key is ignored if it does not exist.
    ///
    /// [https://redis.io/commands/del](https://redis.io/commands/del)
    /// - Returns: A future number of keys that were removed.
    public func delete(_ keys: String...) -> EventLoopFuture<Int> {
        return send(command: "DEL", with: keys)
            .mapFromRESP()
    }

    /// Set a timeout on key. After the timeout has expired, the key will automatically be deleted.
    /// A key with an associated timeout is often said to be volatile in Redis terminology.
    ///
    /// [https://redis.io/commands/expire](https://redis.io/commands/expire)
    /// - Parameters:
    ///     - after: The lifetime (in seconds) the key will expirate at.
    /// - Returns: A future bool indicating if the expiration was set or not.
    public func expire(_ key: String, after deadline: Int) -> EventLoopFuture<Bool> {
        return send(command: "EXPIRE", with: [key, deadline.description])
            .mapFromRESP(to: Int.self)
            .map { return $0 == 1 }
    }

    /// Get the value of a key.
    /// If the key does not exist the value will be `nil`.
    /// An error is resolved if the value stored at key is not a string, because GET only handles string values.
    ///
    /// [https://redis.io/commands/get](https://redis.io/commands/get)
    public func get(_ key: String) -> EventLoopFuture<String?> {
        return send(command: "GET", with: [key])
            .map { return $0.string }
    }

    /// Returns the values of all specified keys, using `.null` to represent non-existant values.
    ///
    /// See [https://redis.io/commands/mget](https://redis.io/commands/mget)
    public func mget(_ keys: [String]) -> EventLoopFuture<[RESPValue]> {
        assert(keys.count > 0, "At least 1 key should be provided.")
        
        return send(command: "MGET", with: keys)
            .mapFromRESP()
    }

    /// Set key to hold the string value.
    /// If key already holds a value, it is overwritten, regardless of its type.
    /// Any previous time to live associated with the key is discarded on successful SET operation.
    ///
    /// [https://redis.io/commands/set](https://redis.io/commands/set)
    public func set(_ key: String, to value: String) -> EventLoopFuture<Void> {
        return send(command: "SET", with: [key, value])
            .map { _ in return () }
    }

    /// Sets each key to the respective new value, overwriting existing values.
    ///
    /// - Note: Use `msetnx` if you don't want to overwrite values.
    ///
    /// See [https://redis.io/commands/mset](https://redis.io/commands/mset)
    public func mset(_ operations: [String: RESPValueConvertible]) -> EventLoopFuture<Void> {
        assert(operations.count > 0, "At least 1 key-value pair should be provided.")

        let args = _convertMSET(operations)
        return send(command: "MSET", with: args)
            .map { _ in return () }
    }

    /// If every key does not exist, sets each key to the respective new value.
    ///
    /// See [https://redis.io/commands/msetnx](https://redis.io/commands/msetnx)
    public func msetnx(_ operations: [String: RESPValueConvertible]) -> EventLoopFuture<Bool> {
        assert(operations.count > 0, "At least 1 key-value pair should be provided.")

        let args = _convertMSET(operations)
        return send(command: "MSETNX", with: args)
            .mapFromRESP(to: Int.self)
            .map { return $0 == 1 }
    }

    @inline(__always)
    private func _convertMSET(_ source: [String: RESPValueConvertible]) -> [RESPValueConvertible] {
        return source.reduce(into: [RESPValueConvertible](), { (result, element) in
            result.append(element.key)
            result.append(element.value)
        })
    }
}

extension RedisCommandExecutor {
    /// Increments the stored value by 1 and returns the new value.
    ///
    /// See [https://redis.io/commands/incr](https://redis.io/commands/incr)
    /// - Returns: The new value after the operation.
    public func increment(_ key: String) -> EventLoopFuture<Int> {
        return send(command: "INCR", with: [key])
            .mapFromRESP()
    }

    /// Increments the stored value by the amount desired and returns the new value.
    ///
    /// See [https://redis.io/commands/incrby](https://redis.io/commands/incrby)
    /// - Returns: The new value after the operation.
    public func increment(_ key: String, by count: Int) -> EventLoopFuture<Int> {
        return send(command: "INCRBY", with: [key, count])
            .mapFromRESP()
    }

    /// Increments the stored value by the amount desired and returns the new value.
    ///
    /// See [https://redis.io/commands/incrbyfloat](https://redis.io/commands/incrbyfloat)
    /// - Returns: The new value after the operation.
    public func increment<T: BinaryFloatingPoint>(_ key: String, by count: T) -> EventLoopFuture<T>
        where T: RESPValueConvertible
    {
        return send(command: "INCRBYFLOAT", with: [key, count])
            .mapFromRESP()
    }

    /// Decrements the stored value by 1 and returns the new value.
    ///
    /// See [https://redis.io/commands/decr](https://redis.io/commands/decr)
    /// - Returns: The new value after the operation.
    public func decrement(_ key: String) -> EventLoopFuture<Int> {
        return send(command: "DECR", with: [key])
            .mapFromRESP()
    }

    /// Decrements the stored valye by the amount desired and returns the new value.
    ///
    /// See [https://redis.io/commands/decrby](https://redis.io/commands/decrby)
    /// - Returns: The new value after the operation.
    public func decrement(_ key: String, by count: Int) -> EventLoopFuture<Int> {
        return send(command: "DECRBY", with: [key, count])
            .mapFromRESP()
    }
}

extension RedisCommandExecutor {
    /// Incrementally iterates over all keys in the currently selected database.
    ///
    /// [https://redis.io/commands/scan](https://redis.io/commands/scan)
    /// - Parameters:
    ///     - startingFrom: The cursor position to start from.
    ///     - count: The number of elements to advance by. Redis default is 10.
    ///     - matching: A glob-style pattern to filter values to be selected from the result set.
    /// - Returns: A cursor position for additional invocations with a limited collection of keys stored in the database.
    @inlinable
    public func scan(
        startingFrom pos: Int = 0,
        count: Int? = nil,
        matching match: String? = nil) -> EventLoopFuture<(Int, [String])>
    {
        return _scan(command: "SCAN", resultType: [String].self, nil, pos, count, match)
    }

    @inline(__always)
    @usableFromInline func _scan<T: RESPValueConvertible>(
        command: String,
        resultType: T.Type,
        _ key: String?,
        _ pos: Int,
        _ count: Int?,
        _ match: String?) -> EventLoopFuture<(Int, T)>
    {
        var args: [RESPValueConvertible] = [pos]

        if let k = key {
            args.insert(k, at: 0)
        }

        if let m = match {
            args.append("match")
            args.append(m)
        }
        if let c = count {
            args.append("count")
            args.append(c)
        }

        let response = send(command: command, with: args).mapFromRESP(to: [RESPValue].self)
        let position = response.flatMapThrowing { result -> Int in
            guard
                let value = result[0].string,
                let position = Int(value)
                else { throw RedisError(identifier: #function, reason: "Unexpected value in response: \(result[0])") }
            return position
        }
        let elements = response
            .map { return $0[1] }
            .mapFromRESP(to: resultType)

        return position.and(elements)
    }
}
