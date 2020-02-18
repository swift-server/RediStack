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

extension RedisClient {
    /// Echos the provided message through the Redis instance.
    ///
    /// See [https://redis.io/commands/echo](https://redis.io/commands/echo)
    /// - Parameter message: The message to echo.
    /// - Returns: The message sent with the command.
    public func echo(_ message: String) -> EventLoopFuture<String> {
        return self.sendCommand(.echo(message))
    }
    
    /// Pings the server, which will respond with a message.
    ///
    /// See [https://redis.io/commands/ping](https://redis.io/commands/ping)
    /// - Parameter message: The optional message that the server should respond with.
    /// - Returns: The provided message or Redis' default response of `"PONG"`.
    public func ping(with message: String? = nil) -> EventLoopFuture<String> {
        return self.sendCommand(.ping(with: message))
    }

    /// Select the Redis logical database having the specified zero-based numeric index.
    /// - Note: New connections always use the database `0`.
    ///
    /// [https://redis.io/commands/select](https://redis.io/commands/select)
    /// - Parameter index: The 0-based index of the database that will receive later commands.
    /// - Returns: A `NIO.EventLoopFuture` that resolves when the operation has succeeded, or fails with a `RedisError`.
    public func select(database index: Int) -> EventLoopFuture<Void> {
        return self.sendCommand(.select(database: index))
            .map { _ in return () }
    }

    /// Swaps the data of two Redis databases by their index IDs.
    ///
    /// See [https://redis.io/commands/swapdb](https://redis.io/commands/swapdb)
    /// - Parameters:
    ///     - first: The index of the first database.
    ///     - second: The index of the second database.
    /// - Returns: A `NIO.EventLoopFuture` that resolves `true` if the swap was successful, or fails with a `RedisError`.
    public func swapDatabase(_ first: Int, with second: Int) -> EventLoopFuture<Bool> {
        return self.sendCommand(.swapdb(first, with: second))
            .map { _ in return true }
    }
    
    /// Requests the client to authenticate with Redis to allow other commands to be executed.
    ///
    /// [https://redis.io/commands/auth](https://redis.io/commands/auth)
    /// - Parameter password: The password to authenticate with.
    /// - Returns: A `NIO.EventLoopFuture` that resolves if the password was accepted, otherwise it fails.
    public func authorize(with password: String) -> EventLoopFuture<Void> {
        return self.sendCommand(.auth(with: password))
            .map { _ in return () }
    }

    /// Removes the specified keys. A key is ignored if it does not exist.
    ///
    /// [https://redis.io/commands/del](https://redis.io/commands/del)
    /// - Parameter keys: A list of keys to delete from the database.
    /// - Returns: The number of keys deleted from the database.
    public func delete(_ keys: [RedisKey]) -> EventLoopFuture<Int> {
        guard keys.count > 0 else { return self.eventLoop.makeSucceededFuture(0) }
        return self.sendCommand(.del(keys))
    }
    
    /// Removes the specified keys. A key is ignored if it does not exist.
    ///
    /// [https://redis.io/commands/del](https://redis.io/commands/del)
    /// - Parameter keys: A list of keys to delete from the database.
    /// - Returns: The number of keys deleted from the database.
    public func delete(_ keys: RedisKey...) -> EventLoopFuture<Int> {
        return self.delete(keys)
    }

    /// Sets a timeout on key. After the timeout has expired, the key will automatically be deleted.
    /// - Note: A key with an associated timeout is often said to be "volatile" in Redis terminology.
    ///
    /// [https://redis.io/commands/expire](https://redis.io/commands/expire)
    /// - Parameters:
    ///     - key: The key to set the expiration on.
    ///     - timeout: The time from now the key will expire at.
    /// - Returns: `true` if the expiration was set.
    public func expire(_ key: RedisKey, after timeout: TimeAmount) -> EventLoopFuture<Bool> {
        return self.sendCommand(.expire(key, after: timeout))
            .map { return $0 == 1 }
    }
    
    /// Incrementally iterates over all keys in the currently selected database.
    ///
    /// [https://redis.io/commands/scan](https://redis.io/commands/scan)
    /// - Parameters:
    ///     - position: The cursor position to start from.
    ///     - count: The number of elements to advance by. Redis default is 10.
    ///     - match: A glob-style pattern to filter values to be selected from the result set.
    /// - Returns: A cursor position for additional invocations with a limited collection of keys found in the database.
    public func scan(
        startingFrom position: UInt = 0,
        count: Int? = nil,
        matching match: String? = nil
    ) -> EventLoopFuture<(UInt, [String])> {
        return self._sendScanCommand(.scan(startingFrom: position, count: count, matching: match))
    }
    
    @usableFromInline
    internal func _sendScanCommand<T: RESPValueConvertible>(
        _ command: NewRedisCommand<[RESPValue]>
    ) -> EventLoopFuture<(UInt, T)>
    {
        return self.sendCommand(command)
            .flatMapThrowing { result throws -> (UInt, T) in
                guard result.count == 2 else {
                    throw RedisClientError.assertionFailure(message: "Unexpected response from scan: \(result)")
                }
                guard let position = UInt(fromRESP: result[0]) else { throw RedisClientError.failedRESPConversion(to: UInt.self) }
                guard let elements = T(fromRESP: result[1]) else { throw RedisClientError.failedRESPConversion(to: T.self) }
                return (position, elements)
            }
    }
}
