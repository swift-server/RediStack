import Foundation
import NIO

extension RedisConnection {
    /// Select the Redis logical database having the specified zero-based numeric index.
    /// New connections always use the database 0.
    ///
    /// [https://redis.io/commands/select](https://redis.io/commands/select)
    public func select(_ id: Int) -> EventLoopFuture<Void> {
        return command("SELECT", arguments: [RESPValue(bulk: id.description)])
            .map { _ in return () }
    }

    /// Request for authentication in a password-protected Redis server.
    ///
    /// [https://redis.io/commands/auth](https://redis.io/commands/auth)
    public func authorize(with password: String) -> EventLoopFuture<Void> {
        return command("AUTH", arguments: [RESPValue(bulk: password)])
            .map { _ in return () }
    }

    /// Removes the specified keys. A key is ignored if it does not exist.
    ///
    /// [https://redis.io/commands/del](https://redis.io/commands/del)
    /// - Returns: A future number of keys that were removed.
    public func delete(_ keys: String...) -> EventLoopFuture<Int> {
        let keyArgs = keys.map { RESPValue(bulk: $0) }
        return command("DEL", arguments: keyArgs)
            .flatMapThrowing { res in
                guard let count = res.int else {
                    throw RedisError(identifier: "delete", reason: "Unexpected response: \(res)")
                }
                return count
            }
    }

    /// Set a timeout on key. After the timeout has expired, the key will automatically be deleted.
    /// A key with an associated timeout is often said to be volatile in Redis terminology.
    ///
    /// [https://redis.io/commands/expire](https://redis.io/commands/expire)
    /// - Parameters:
    ///     - after: The lifetime (in seconds) the key will expirate at.
    /// - Returns: A future bool indicating if the expiration was set or not.
    public func expire(_ key: String, after deadline: Int) -> EventLoopFuture<Bool> {
        return command("EXPIRE", arguments: [RESPValue(bulk: key), RESPValue(bulk: deadline.description)])
            .flatMapThrowing { res in
                guard let value = res.int else {
                    throw RedisError(identifier: "expire", reason: "Unexpected response: \(res)")
                }
                return value == 1
            }
    }

    /// Get the value of a key.
    /// If the key does not exist the value will be `nil`.
    /// An error is resolved if the value stored at key is not a string, because GET only handles string values.
    ///
    /// [https://redis.io/commands/get](https://redis.io/commands/get)
    public func get(_ key: String) -> EventLoopFuture<String?> {
        return command("GET", arguments: [RESPValue(bulk: key)])
            .map { return $0.string }
    }

    /// Set key to hold the string value.
    /// If key already holds a value, it is overwritten, regardless of its type.
    /// Any previous time to live associated with the key is discarded on successful SET operation.
    ///
    /// [https://redis.io/commands/set](https://redis.io/commands/set)
    public func set(_ key: String, to value: String) -> EventLoopFuture<Void> {
        return command("SET", arguments: [RESPValue(bulk: key), RESPValue(bulk: value)])
            .map { _ in return () }
    }

    /// Echos the provided message through the Redis instance.
    /// - Parameter message: The message to echo.
    /// - Returns: The message sent with the command.
    public func echo(_ message: String) -> EventLoopFuture<String> {
        return send(command: "ECHO", with: [message])
            .flatMapThrowing {
                guard let response = $0.string else { throw RedisError.respConversion(to: String.self) }
                return response
            }
    }

    /// Pings the server, which will respond with a message.
    /// - Parameter with: The optional message that the server should respond with.
    /// - Returns: The provided message or Redis' default response of `"PONG"`.
    public func ping(with message: String? = nil) -> EventLoopFuture<String> {
        let arg = message != nil ? [message] : []
        return send(command: "PING", with: arg)
            .flatMapThrowing {
                guard let response = $0.string else { throw RedisError.respConversion(to: String.self) }
                return response
            }
    }

    /// Swaps the data of two Redis database by their index ID.
    /// - Parameters:
    ///     - firstIndex: The index of the first database.
    ///     - secondIndex: The index of the second database.
    /// - Returns: `true` if the swap was successful.
    public func swapdb(firstIndex: Int, secondIndex: Int) -> EventLoopFuture<Bool> {
        return send(command: "SWAPDB", with: [firstIndex, secondIndex])
            .flatMapThrowing {
                guard let response = $0.string else { throw RedisError.respConversion(to: String.self) }
                return response == "OK"
            }
    }
}
