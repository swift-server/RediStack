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

import struct NIO.TimeAmount

extension NewRedisCommand {
    /// Echos the provided message through the Redis instance.
    ///
    /// See [https://redis.io/commands/echo](https://redis.io/commands/echo)
    /// - Parameter message: The message to echo.
    public static func echo(_ message: String) -> NewRedisCommand<String> {
        let args = [RESPValue(bulk: message)]
        return .init(keyword: "ECHO", arguments: args)
    }
    
    /// Pings the server, which will respond with a message.
    ///
    /// See [https://redis.io/commands/ping](https://redis.io/commands/ping)
    /// - Parameter message: The optional message that the server should respond with.
    public static func ping(with message: String? = nil) -> NewRedisCommand<String> {
        let args: [RESPValue] = message != nil
            ? [.init(bulk: message!)] // safe because we did a nil pre-check
            : []
        return .init(keyword: "PING", arguments: args)
    }

    /// Select the Redis logical database having the specified zero-based numeric index.
    /// - Note: New connections always use the database `0`.
    ///
    /// [https://redis.io/commands/select](https://redis.io/commands/select)
    /// - Parameter index: The 0-based index of the database that will receive later commands.
    public static func select(database index: Int) -> NewRedisCommand<String> {
        let args = [RESPValue(bulk: index)]
        return .init(keyword: "SELECT", arguments: args)
    }

    /// Swaps the data of two Redis databases by their index IDs.
    ///
    /// See [https://redis.io/commands/swapdb](https://redis.io/commands/swapdb)
    /// - Parameters:
    ///     - first: The index of the first database.
    ///     - second: The index of the second database.
    public static func swapdb(_ first: Int, with second: Int) -> NewRedisCommand<String> {
        let args: [RESPValue] = [
            .init(bulk: first),
            .init(bulk: second)
        ]
        return .init(keyword: "SWAPDB", arguments: args)
    }
    
    /// Requests the client to authenticate with Redis to allow other commands to be executed.
    ///
    /// [https://redis.io/commands/auth](https://redis.io/commands/auth)
    /// - Parameter password: The password to authenticate with.
    public static func auth(with password: String) -> NewRedisCommand<String> {
        let args = [RESPValue(bulk: password)]
        return .init(keyword: "AUTH", arguments: args)
    }

    /// Removes the specified keys. A key is ignored if it does not exist.
    ///
    /// [https://redis.io/commands/del](https://redis.io/commands/del)
    /// - Parameter keys: A list of keys to delete from the database.
    public static func del(_ keys: [RedisKey]) -> NewRedisCommand<Int> {
        let args = keys.map(RESPValue.init)
        return .init(keyword: "DEL", arguments: args)
    }

    /// Sets a timeout on key. After the timeout has expired, the key will automatically be deleted.
    /// - Note: A key with an associated timeout is often said to be "volatile" in Redis terminology.
    ///
    /// [https://redis.io/commands/expire](https://redis.io/commands/expire)
    /// - Parameters:
    ///     - key: The key to set the expiration on.
    ///     - timeout: The time from now the key will expire at.
    public static func expire(_ key: RedisKey, after timeout: TimeAmount) -> NewRedisCommand<Int> {
        let args: [RESPValue] = [
            .init(bulk: key),
            .init(bulk: timeout.seconds)
        ]
        return .init(keyword: "EXPIRE", arguments: args)
    }

    /// Incrementally iterates over all keys in the currently selected database.
    ///
    /// [https://redis.io/commands/scan](https://redis.io/commands/scan)
    /// - Parameters:
    ///     - position: The cursor position to start from.
    ///     - count: The number of elements to advance by. Redis default is 10.
    ///     - match: A glob-style pattern to filter values to be selected from the result set.
    public static func scan(
        startingFrom position: UInt = 0,
        count: Int? = nil,
        matching match: String? = nil
    ) -> NewRedisCommand<[RESPValue]> { // Until tuples can conform to protocols, we have to lose type information
        var args: [RESPValue] = [.init(bulk: position)]
        if let m = match { args.append(convertingContentsOf: ["match", m]) }
        if let c = count { args.append(convertingContentsOf: ["count", c.description]) }
        return .init(keyword: "SCAN", arguments: args)
    }
}
