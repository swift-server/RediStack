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
        let args = [RESPValue(bulk: message)]
        return send(command: "ECHO", with: args)
            .tryConverting()
    }

    /// Pings the server, which will respond with a message.
    ///
    /// See [https://redis.io/commands/ping](https://redis.io/commands/ping)
    /// - Parameter message: The optional message that the server should respond with.
    /// - Returns: The provided message or Redis' default response of `"PONG"`.
    public func ping(with message: String? = nil) -> EventLoopFuture<String> {
        let args: [RESPValue] = message != nil
            ? [.init(bulk: message!)] // safe because we did a nil pre-check
            : []
        return send(command: "PING", with: args)
            .tryConverting()
    }

    /// Select the Redis logical database having the specified zero-based numeric index.
    /// - Note: New connections always use the database `0`.
    ///
    /// [https://redis.io/commands/select](https://redis.io/commands/select)
    /// - Parameter index: The 0-based index of the database that will receive later commands.
    /// - Returns: An `EventLoopFuture` that resolves when the operation has succeeded, or fails with a `RedisError`.
    public func select(database index: Int) -> EventLoopFuture<Void> {
        let args = [RESPValue(bulk: index)]
        return send(command: "SELECT", with: args)
            .map { _ in return () }
    }

    /// Swaps the data of two Redis databases by their index IDs.
    ///
    /// See [https://redis.io/commands/swapdb](https://redis.io/commands/swapdb)
    /// - Parameters:
    ///     - first: The index of the first database.
    ///     - second: The index of the second database.
    /// - Returns: `true` if the swap was successful.
    public func swapDatabase(_ first: Int, with second: Int) -> EventLoopFuture<Bool> {
        let args: [RESPValue] = [
            .init(bulk: first),
            .init(bulk: second)
        ]
        return send(command: "SWAPDB", with: args)
            .tryConverting(to: String.self)
            .map { return $0 == "OK" }
    }
    
    /// Requests the client to authenticate with Redis to allow other commands to be executed.
    ///
    /// [https://redis.io/commands/auth](https://redis.io/commands/auth)
    /// - Parameter password: The password to authenticate with.
    /// - Returns: A `NIO.EventLoopFuture` that resolves if the password was accepted, otherwise it fails.
    public func authorize(with password: String) -> EventLoopFuture<Void> {
        let args = [RESPValue(bulk: password)]
        return send(command: "AUTH", with: args)
            .map { _ in return () }
    }

    /// Removes the specified keys. A key is ignored if it does not exist.
    ///
    /// [https://redis.io/commands/del](https://redis.io/commands/del)
    /// - Parameter keys: A list of keys to delete from the database.
    /// - Returns: The number of keys deleted from the database.
    public func delete(_ keys: [RedisKey]) -> EventLoopFuture<Int> {
        guard keys.count > 0 else { return self.eventLoop.makeSucceededFuture(0) }
        
        let args = keys.map(RESPValue.init)
        return send(command: "DEL", with: args)
            .tryConverting()
    }
    
    /// Removes the specified keys. A key is ignored if it does not exist.
    ///
    /// [https://redis.io/commands/del](https://redis.io/commands/del)
    /// - Parameter keys: A list of keys to delete from the database.
    /// - Returns: The number of keys deleted from the database.
    public func delete(_ keys: RedisKey...) -> EventLoopFuture<Int> {
        return self.delete(keys)
    }

    /// Checks the existence of the provided keys in the database.
    ///
    /// [https://redis.io/commands/exists](https://redis.io/commands/exists)
    /// - Parameter keys: A list of keys whose existence will be checked for in the database.
    /// - Returns: The number of provided keys which exist in the database.
    public func exists(_ keys: [RedisKey]) -> EventLoopFuture<Int> {
        let args: [RESPValue] = keys.map {
            RESPValue(from: $0)
        }
        return self.send(command: "EXISTS", with: args)
            .tryConverting(to: Int.self)
    }

    /// Checks the existence of the provided keys in the database.
    ///
    /// [https://redis.io/commands/exists](https://redis.io/commands/exists)
    /// - Parameter keys: A list of keys whose existence will be checked for in the database.
    /// - Returns: The number of provided keys which exist in the database.
    public func exists(_ keys: RedisKey...) -> EventLoopFuture<Int> {
        return self.exists(keys)
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
        let args: [RESPValue] = [
            .init(from: key),
            .init(bulk: timeout.seconds)
        ]
        return send(command: "EXPIRE", with: args)
            .tryConverting(to: Int.self)
            .map { return $0 == 1 }
    }
}

// MARK: TTL

extension RedisClient {
    /// Returns the remaining time-to-live (in seconds) of the provided key.
    ///
    /// [https://redis.io/commands/ttl](https://redis.io/commands/ttl)
    /// - Parameter key: The key to check the time-to-live on.
    /// - Returns: The number of seconds before the given key will expire.
    public func ttl(_ key: RedisKey) -> EventLoopFuture<RedisKeyLifetime> {
        let args: [RESPValue] = [RESPValue(from: key)]
        return self.send(command: "TTL", with: args)
            .tryConverting(to: Int64.self)
            .map { RedisKeyLifetime(seconds: $0) }
    }

    /// Returns the remaining time-to-live (in milliseconds) of the provided key.
    ///
    /// [https://redis.io/commands/pttl](https://redis.io/commands/pttl)
    /// - Parameter key: The key to check the time-to-live on.
    /// - Returns: The number of milliseconds before the given key will expire.
    public func pttl(_ key: RedisKey) -> EventLoopFuture<RedisKeyLifetime> {
        let args: [RESPValue] = [RESPValue(from: key)]
        return self.send(command: "PTTL", with: args)
            .tryConverting(to: Int64.self)
            .map { RedisKeyLifetime(milliseconds: $0) }
    }
}


/// The lifetime of a `RedisKey` as determined by `ttl` or `pttl`.
public enum RedisKeyLifetime: Hashable {
    /// The key does not exist.
    case keyDoesNotExist
    /// The key exists but has no expiry associated with it.
    case unlimited
    /// The key exists for the given lifetime.
    case limited(Lifetime)
}

extension RedisKeyLifetime {
    /// The lifetime for a `RedisKey` which has an expiry set.
    public enum Lifetime: Comparable, Hashable {
        /// The remaining time-to-live in seconds.
        case seconds(Int64)
        /// The remaining time-to-live in milliseconds.
        case milliseconds(Int64)

        /// The remaining time-to-live.
        public var timeAmount: TimeAmount {
            switch self {
            case .seconds(let amount): return .seconds(amount)
            case .milliseconds(let amount): return .milliseconds(amount)
            }
        }

        public static func <(lhs: Lifetime, rhs: Lifetime) -> Bool {
            return lhs.timeAmount < rhs.timeAmount
        }

        public static func ==(lhs: Lifetime, rhs: Lifetime) -> Bool {
            return lhs.timeAmount == rhs.timeAmount
        }
    }
}

extension RedisKeyLifetime {
    /// The remaining time-to-live for the key, or `nil` if the key does not exist or will not expire.
    public var timeAmount: TimeAmount? {
        switch self {
        case .keyDoesNotExist, .unlimited: return nil
        case .limited(let lifetime): return lifetime.timeAmount
        }
    }
}

extension RedisKeyLifetime {
    internal init(seconds: Int64) {
        switch seconds {
        case -2:
            self = .keyDoesNotExist
        case -1:
            self = .unlimited
        default:
            self = .limited(.seconds(seconds))
        }
    }

    internal init(milliseconds: Int64) {
        switch milliseconds {
        case -2:
            self = .keyDoesNotExist
        case -1:
            self = .unlimited
        default:
            self = .limited(.milliseconds(milliseconds))
        }
    }
}

// MARK: Scan

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
    ) -> EventLoopFuture<(Int, [String])> {
        return _scan(command: "SCAN", nil, position, match, count)
    }

    @usableFromInline
    internal func _scan<T>(
        command: String,
        resultType: T.Type = T.self,
        _ key: RedisKey?,
        _ pos: Int,
        _ match: String?,
        _ count: Int?
    ) -> EventLoopFuture<(Int, T)>
        where
        T: RESPValueConvertible
    {
        var args: [RESPValue] = [.init(bulk: pos)]

        if let k = key {
            args.insert(.init(from: k), at: 0)
        }

        if let m = match {
            args.append(.init(bulk: "match"))
            args.append(.init(bulk: m))
        }
        if let c = count {
            args.append(.init(bulk: "count"))
            args.append(.init(bulk: c))
        }

        let response = send(command: command, with: args).tryConverting(to: [RESPValue].self)
        let position = response.flatMapThrowing { result -> Int in
            guard
                let value = result[0].string,
                let position = Int(value)
            else {
                throw RedisClientError.assertionFailure(message: "Unexpected value in response: \(result[0])")
            }
            return position
        }
        let elements = response
            .map { return $0[1] }
            .tryConverting(to: resultType)

        return position.and(elements)
    }
}
