//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2019-2020 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOCore

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension RedisClient {
    /// Echos the provided message through the Redis instance.
    ///
    /// See [https://redis.io/commands/echo](https://redis.io/commands/echo)
    /// - Parameter message: The message to echo.
    /// - Returns: The message sent with the command.
    public func echo(_ message: String) async throws -> String {
        try await echo(message).get()
    }

    /// Pings the server, which will respond with a message.
    ///
    /// See [https://redis.io/commands/ping](https://redis.io/commands/ping)
    /// - Parameter message: The optional message that the server should respond with.
    /// - Returns: The provided message or Redis' default response of `"PONG"`.
    public func ping(with message: String? = nil) async throws -> String {
        try await ping(with: message).get()
    }

    /// Select the Redis logical database having the specified zero-based numeric index.
    /// - Note: New connections always use the database `0`.
    ///
    /// [https://redis.io/commands/select](https://redis.io/commands/select)
    /// - Parameter index: The 0-based index of the database that will receive later commands.
    /// - Returns: An `EventLoopFuture` that resolves when the operation has succeeded, or fails with a `RedisError`.
    public func select(database index: Int) async throws {
        try await select(database: index).get()
    }

    /// Swaps the data of two Redis databases by their index IDs.
    ///
    /// See [https://redis.io/commands/swapdb](https://redis.io/commands/swapdb)
    /// - Parameters:
    ///     - first: The index of the first database.
    ///     - second: The index of the second database.
    /// - Returns: `true` if the swap was successful.
    public func swapDatabase(_ first: Int, with second: Int) async throws -> Bool {
        try await swapDatabase(first, with: second).get()
    }
    
    /// Requests the client to authenticate with Redis to allow other commands to be executed.
    ///
    /// [https://redis.io/commands/auth](https://redis.io/commands/auth)
    /// - Parameter password: The password to authenticate with.
    /// - Returns: A `NIO.EventLoopFuture` that resolves if the password was accepted, otherwise it fails.
    public func authorize(with password: String) async throws {
        try await authorize(with: password).get()
    }

    /// Requests the client to authenticate with Redis to allow other commands to be executed.
    /// - Parameters:
    ///     - username: The username to authenticate with.
    ///     - password: The password to authenticate with.
    ///  Warning: This function should only be used if you are running against Redis 6 or higher.
    public func authorize(
        username: String,
        password: String
    ) async throws -> Void {
        try await authorize(username: username, password: password).get()
    }

    /// Removes the specified keys. A key is ignored if it does not exist.
    ///
    /// [https://redis.io/commands/del](https://redis.io/commands/del)
    /// - Parameter keys: A list of keys to delete from the database.
    /// - Returns: The number of keys deleted from the database.
    public func delete(_ keys: [RedisKey]) async throws -> Int {
        try await delete(keys).get()
    }
    
    /// Removes the specified keys. A key is ignored if it does not exist.
    ///
    /// [https://redis.io/commands/del](https://redis.io/commands/del)
    /// - Parameter keys: A list of keys to delete from the database.
    /// - Returns: The number of keys deleted from the database.
    public func delete(_ keys: RedisKey...) async throws -> Int {
        try await delete(keys).get()
    }

    /// Checks the existence of the provided keys in the database.
    ///
    /// [https://redis.io/commands/exists](https://redis.io/commands/exists)
    /// - Parameter keys: A list of keys whose existence will be checked for in the database.
    /// - Returns: The number of provided keys which exist in the database.
    public func exists(_ keys: [RedisKey]) async throws -> Int {
        try await exists(keys).get()
    }

    /// Checks the existence of the provided keys in the database.
    ///
    /// [https://redis.io/commands/exists](https://redis.io/commands/exists)
    /// - Parameter keys: A list of keys whose existence will be checked for in the database.
    /// - Returns: The number of provided keys which exist in the database.
    public func exists(_ keys: RedisKey...) async throws -> Int {
        try await exists(keys).get()
    }

    /// Sets a timeout on key. After the timeout has expired, the key will automatically be deleted.
    /// - Note: A key with an associated timeout is often said to be "volatile" in Redis terminology.
    ///
    /// [https://redis.io/commands/expire](https://redis.io/commands/expire)
    /// - Parameters:
    ///     - key: The key to set the expiration on.
    ///     - timeout: The time from now the key will expire at.
    /// - Returns: `true` if the expiration was set.
    public func expire(_ key: RedisKey, after timeout: TimeAmount) async throws -> Bool {
        try await expire(key, after: timeout).get()
    }
}

// MARK: TTL

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension RedisClient {
    /// Returns the remaining time-to-live (in seconds) of the provided key.
    ///
    /// [https://redis.io/commands/ttl](https://redis.io/commands/ttl)
    /// - Parameter key: The key to check the time-to-live on.
    /// - Returns: The number of seconds before the given key will expire.
    public func ttl(_ key: RedisKey) async throws -> RedisKey.Lifetime {
        try await ttl(key).get()
    }

    /// Returns the remaining time-to-live (in milliseconds) of the provided key.
    ///
    /// [https://redis.io/commands/pttl](https://redis.io/commands/pttl)
    /// - Parameter key: The key to check the time-to-live on.
    /// - Returns: The number of milliseconds before the given key will expire.
    public func pttl(_ key: RedisKey) async throws -> RedisKey.Lifetime {
        try await pttl(key).get()
    }
}

// MARK: Scan

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension RedisClient {
    /// Incrementally iterates over all keys in the currently selected database.
    ///
    /// [https://redis.io/commands/scan](https://redis.io/commands/scan)
    /// - Parameters:
    ///     - position: The cursor position to start from.
    ///     - match: A glob-style pattern to filter values to be selected from the result set.
    ///     - count: The number of elements to advance by. Redis default is 10.
    /// - Returns: A cursor position for additional invocations with a limited collection of keys found in the database.
    public func scan(
        startingFrom position: Int = 0,
        matching match: String? = nil,
        count: Int? = nil
    ) async throws -> (Int, [String]) {
        try await scan(startingFrom: position, matching: match, count: count).get()
    }
}
