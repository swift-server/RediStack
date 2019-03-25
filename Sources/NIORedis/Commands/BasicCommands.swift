import Foundation
import NIO

extension RedisCommandExecutor {
    /// Echos the provided message through the Redis instance.
    ///
    /// See [https://redis.io/commands/echo](https://redis.io/commands/echo)
    /// - Parameter message: The message to echo.
    /// - Returns: The message sent with the command.
    @inlinable
    public func echo(_ message: String) -> EventLoopFuture<String> {
        return send(command: "ECHO", with: [message])
            .mapFromRESP()
    }

    /// Pings the server, which will respond with a message.
    ///
    /// See [https://redis.io/commands/ping](https://redis.io/commands/ping)
    /// - Parameter message: The optional message that the server should respond with.
    /// - Returns: The provided message or Redis' default response of `"PONG"`.
    @inlinable
    public func ping(with message: String? = nil) -> EventLoopFuture<String> {
        let arg = message != nil ? [message] : []
        return send(command: "PING", with: arg)
            .mapFromRESP()
    }

    /// Request for authentication in a password-protected Redis server.
    ///
    /// [https://redis.io/commands/auth](https://redis.io/commands/auth)
    /// - Parameter password: The password being used to access the Redis server.
    /// - Returns: An `EventLoopFuture` that resolves when the connection has been authorized, or fails with a `RedisError`.
    @inlinable
    public func authorize(with password: String) -> EventLoopFuture<Void> {
        return send(command: "AUTH", with: [password])
            .map { _ in return () }
    }

    /// Select the Redis logical database having the specified zero-based numeric index.
    /// - Note: New connections always use the database `0`.
    ///
    /// [https://redis.io/commands/select](https://redis.io/commands/select)
    /// - Parameter index: The 0-based index of the database that will receive later commands.
    /// - Returns: An `EventLoopFuture` that resolves when the operation has succeeded, or fails with a `RedisError`.
    @inlinable
    public func select(database index: Int) -> EventLoopFuture<Void> {
        return send(command: "SELECT", with: [index])
            .map { _ in return () }
    }

    /// Swaps the data of two Redis databases by their index IDs.
    ///
    /// See [https://redis.io/commands/swapdb](https://redis.io/commands/swapdb)
    /// - Parameters:
    ///     - first: The index of the first database.
    ///     - second: The index of the second database.
    /// - Returns: `true` if the swap was successful.
    @inlinable
    public func swapDatabase(_ first: Int, with second: Int) -> EventLoopFuture<Bool> {
        /// connection.swapDatabase(index: 0, withIndex: 10)
        return send(command: "SWAPDB", with: [first, second])
            .mapFromRESP(to: String.self)
            .map { return $0 == "OK" }
    }

    /// Removes the specified keys. A key is ignored if it does not exist.
    ///
    /// [https://redis.io/commands/del](https://redis.io/commands/del)
    /// - Parameter keys: A list of keys to delete from the database.
    /// - Returns: The number of keys deleted from the database.
    @inlinable
    public func delete(_ keys: [String]) -> EventLoopFuture<Int> {
        guard keys.count > 0 else { return self.eventLoop.makeSucceededFuture(0) }
        
        return send(command: "DEL", with: keys)
            .mapFromRESP()
    }

    /// Sets a timeout on key. After the timeout has expired, the key will automatically be deleted.
    /// - Note: A key with an associated timeout is often said to be "volatile" in Redis terminology.
    ///
    /// [https://redis.io/commands/expire](https://redis.io/commands/expire)
    /// - Parameters:
    ///     - key: The key to set the expiration on.
    ///     - deadline: The time from now the key will expire at.
    /// - Returns: `true` if the expiration was set.
    @inlinable
    public func expire(_ key: String, after deadline: TimeAmount) -> EventLoopFuture<Bool> {
        let amount = deadline.nanoseconds / 1_000_000_000
        return send(command: "EXPIRE", with: [key, amount])
            .mapFromRESP(to: Int.self)
            .map { return $0 == 1 }
    }
}

// MARK: Scan

extension RedisCommandExecutor {
    /// Incrementally iterates over all keys in the currently selected database.
    ///
    /// [https://redis.io/commands/scan](https://redis.io/commands/scan)
    /// - Parameters:
    ///     - position: The cursor position to start from.
    ///     - count: The number of elements to advance by. Redis default is 10.
    ///     - match: A glob-style pattern to filter values to be selected from the result set.
    /// - Returns: A cursor position for additional invocations with a limited collection of keys found in the database.
    @inlinable
    public func scan(
        startingFrom position: Int = 0,
        count: Int? = nil,
        matching match: String? = nil
    ) -> EventLoopFuture<(Int, [String])> {
        return _scan(command: "SCAN", nil, position, count, match)
    }

    @usableFromInline
    func _scan<T>(
        command: String,
        resultType: T.Type = T.self,
        _ key: String?,
        _ pos: Int,
        _ count: Int?,
        _ match: String?
    ) -> EventLoopFuture<(Int, T)>
        where
        T: RESPValueConvertible
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
            else {
                throw RedisError(
                    identifier: #function,
                    reason: "Unexpected value in response: \(result[0])"
                )
            }
            return position
        }
        let elements = response
            .map { return $0[1] }
            .mapFromRESP(to: resultType)

        return position.and(elements)
    }
}
