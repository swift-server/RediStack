//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2020-2022 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct Logging.Logger
import NIO

// MARK: Key

extension RedisCommand {
    /// [DEL](https://redis.io/commands/del)
    /// - Parameter keys: The list of keys to delete from the database.
    public static func del(_ keys: [RedisKey]) -> RedisCommand<Int> {
        let args = keys.map(RESPValue.init(from:))
        return .init(keyword: "DEL", arguments: args)
    }

    /// [EXISTS](https://redis.io/commands/exists)
    /// - Parameter keys: A list of keys whose existence will be checked for in the database.
    public static func exists(_ keys: [RedisKey]) -> RedisCommand<Int> {
        let args = keys.map(RESPValue.init(from:))
        return .init(keyword: "EXISTS", arguments: args)
    }

    /// [EXISTS](https://redis.io/commands/exists)
    /// - Parameter keys: A list of keys whose existence will be checked for in the database.
    public static func exists(_ keys: RedisKey...) -> RedisCommand<Int> {
        return .exists(keys)
    }
    
    /// [EXPIRE](https://redis.io/commands/expire)
    /// - Note: A key with an associated timeout is often said to be "volatile" in Redis terminology.
    /// - Parameters:
    ///     - key: The key to set the expiration on.
    ///     - timeout: The time from now the key will expire at.
    public static func expire(_ key: RedisKey, after timeout: TimeAmount) -> RedisCommand<Bool> {
        let args: [RESPValue] = [
            .init(from: key),
            .init(bulk: timeout.seconds)
        ]
        return .init(keyword: "EXPIRE", arguments: args)
    }
    
    /// [TTL](https://redis.io/commands/ttl)
    /// - Parameter key: The key to check the time-to-live on.
    public static func ttl(_ key: RedisKey) -> RedisCommand<RedisKey.Lifetime> {
        let args = [RESPValue(from: key)]
        return .init(keyword: "TTL", arguments: args) {
            return .init(seconds: try $0.map())
        }
    }
    
    /// [PTTL](https://redis.io/commands/pttl)
    /// - Parameter key: The key to check the time-to-live on.
    public static func pttl(_ key: RedisKey) -> RedisCommand<RedisKey.Lifetime> {
        let args = [RESPValue(from: key)]
        return .init(keyword: "PTTL", arguments: args) {
            return .init(milliseconds: try $0.map())
        }
    }

    /// [KEYS](https://redis.io/commands/keys)
    /// - Parameter pattern: The key pattern to search for matching keys that exist in Redis.
    public static func keys(matching pattern: String) -> RedisCommand<[RedisKey]> {
        return .init(keyword: "KEYS", arguments: [pattern.convertedToRESPValue()])
    }
    
    /// [SCAN](https://redis.io/commands/scan)
    /// - Parameters:
    ///     - position: The cursor position to start from.
    ///     - match: A glob-style pattern to filter values to be selected from the result set.
    ///     - count: The number of elements to advance by. Redis default is 10.
    public static func scan(
        startingFrom position: Int = 0,
        matching match: String? = nil,
        count: Int? = nil
    ) -> RedisCommand<(Int, [RedisKey])> {
        return ._scan(keyword: "SCAN", nil, position, match, count, { try $0.map() })
    }
}

// MARK: -

extension RedisClient {
    /// Deletes the given keys. Any key that does not exist is ignored.
    ///
    /// See ``RedisCommand/del(_:)``.
    /// - Parameters:
    ///     - keys: The list of keys to delete from the database.
    ///     - eventLoop: An optional event loop to hop to for any further chaining on the returned event loop future.
    ///     - logger: An optional logger instance to use for logs generated from this command.
    /// - Returns: A `NIO.EventLoopFuture` that resolves the number of keys that were deleted from the database.
    public func delete(
        _ keys: RedisKey...,
        eventLoop: EventLoop? = nil,
        logger: Logger? = nil
    ) -> EventLoopFuture<Int> {
        return self.delete(keys, eventLoop: eventLoop, logger: logger)
    }

    /// Deletes the given keys. Any key that does not exist is ignored.
    ///
    /// See ``RedisCommand/del(_:)``
    /// - Parameters:
    ///     - keys: The list of keys to delete from the database.
    ///     - eventLoop: An optional event loop to hop to for any further chaining on the returned event loop future.
    ///     - logger: An optional logger instance to use for logs generated from this command.
    /// - Returns: A `NIO.EventLoopFuture` that resolves the number of keys that were deleted from the database.
    public func delete(
        _ keys: [RedisKey],
        eventLoop: EventLoop? = nil,
        logger: Logger? = nil
    ) -> EventLoopFuture<Int> {
        guard keys.count > 0 else { return self.eventLoop.makeSucceededFuture(0) }
        return self.send(.del(keys), eventLoop: eventLoop, logger: logger)
    }

    /// Sets a timeout on key. After the timeout has expired, the key will automatically be deleted.
    ///
    /// See ``RedisCommand/expire(_:after:)``
    /// - Parameters:
    ///     - key: The key to set the expiration on.
    ///     - timeout: The time from now the key will expire at.
    ///     - eventLoop: An optional event loop to hop to for any further chaining on the returned event loop future.
    ///     - logger: An optional logger instance to use for logs generated from this command.
    /// - Returns: A `NIO.EventLoopFuture` that resolves `true` if the expiration was set and `false` if it wasn't.
    public func expire(
        _ key: RedisKey,
        after timeout: TimeAmount,
        eventLoop: EventLoop? = nil,
        logger: Logger? = nil
    ) -> EventLoopFuture<Bool> {
        return self.send(.expire(key, after: timeout), eventLoop: eventLoop, logger: logger)
    }

    /// Searches the keys in the database that match the given pattern.
    ///
    /// See ``RedisCommand/keys(matching:)``
    /// - Parameters:
    ///     - pattern: The key pattern to search for matching keys that exist in Redis.
    ///     - eventLoop: An optional event loop to hop to for any further chaining on the returned event loop future.
    ///     - logger: An optional logger instance to use for logs generated from this command.     
    /// - Returns: A result set of ``RedisKey`` values that exist and match the provided pattern.
    public func listKeys(
        matching pattern: String,
        eventLoop: EventLoop? = nil,
        logger: Logger? = nil
    ) -> EventLoopFuture<[RedisKey]> {
        return self.send(.keys(matching: pattern), eventLoop: eventLoop, logger: logger)
    }

    /// Incrementally iterates over all keys in the currently selected database.
    ///
    /// See ``RedisCommand/scan(startingFrom:matching:count:)``
    /// - Parameters:
    ///     - position: The cursor position to start from.
    ///     - match: A glob-style pattern to filter values to be selected from the result set.
    ///     - count: The number of elements to advance by. Redis default is 10.
    ///     - eventLoop: An optional event loop to hop to for any further chaining on the returned event loop future.
    ///     - logger: An optional logger instance to use for logs generated from this command.
    /// - Returns: A cursor position for additional invocations with a limited collection of keys found in the database.
    public func scanKeys(
        startingFrom position: Int = 0,
        matching match: String? = nil,
        count: Int? = nil,
        eventLoop: EventLoop? = nil,
        logger: Logger? = nil
    ) -> EventLoopFuture<(Int, [RedisKey])> {
        return self.send(.scan(startingFrom: position, matching: match, count: count), eventLoop: eventLoop, logger: logger)
    }
}
