import Foundation
import NIO

extension RedisCommandExecutor {
    /// Select the Redis logical database having the specified zero-based numeric index.
    /// New connections always use the database `0`.
    ///
    /// [https://redis.io/commands/select](https://redis.io/commands/select)
    public func select(database id: Int) -> EventLoopFuture<Void> {
        return send(command: "SELECT", with: [id.description])
            .map { _ in return () }
    }

    /// Request for authentication in a password-protected Redis server.
    ///
    /// [https://redis.io/commands/auth](https://redis.io/commands/auth)
    public func authorize(with password: String) -> EventLoopFuture<Void> {
        return send(command: "AUTH", with: [password])
            .map { _ in return () }
    }

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

    /// Set key to hold the string value.
    /// If key already holds a value, it is overwritten, regardless of its type.
    /// Any previous time to live associated with the key is discarded on successful SET operation.
    ///
    /// [https://redis.io/commands/set](https://redis.io/commands/set)
    public func set(_ key: String, to value: String) -> EventLoopFuture<Void> {
        return send(command: "SET", with: [key, value])
            .map { _ in return () }
    }

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
