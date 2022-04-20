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

// MARK: Connection

extension RedisCommand {
    /// [ECHO](https://redis.io/commands/echo)
    /// - Parameter message: The message to echo.
    public static func echo(_ message: String) -> RedisCommand<String> {
        let args = [RESPValue(bulk: message)]
        return .init(keyword: "ECHO", arguments: args)
    }

    /// [PING](https://redis.io/commands/ping)
    /// - Parameter message: The optional message that the server should respond with instead of the default.
    public static func ping(with message: String? = nil) -> RedisCommand<String> {
        let args = message.map { [RESPValue(bulk: $0)] } ?? []
        return .init(keyword: "PING", arguments: args) {
            // because PING is a special command allowed during pub/sub, we do manual conversion
            // this is because the response format is different in pub/sub ([pong,<message>])
            guard let response = $0.string ?? $0.array?[1].string else {
                throw RedisClientError.assertionFailure(message: "ping message not found")
            }
            // if no message was sent in the ping in pubsub, then the response will be an empty string
            // so we mimic a normal PONG response as if we weren't in pubsub
            return response.isEmpty ? "PONG" : response
        }
    }

    /// [PING](https://redis.io/commands/ping)
    public static var ping: RedisCommand<String> { Self.ping(with: nil) }

    /// [AUTH](https://redis.io/commands/auth)
    /// - Parameter password: The password to authenticate with.
    public static func auth(with password: String) -> RedisCommand<Void> {
        let args = [RESPValue(bulk: password)]
        return .init(keyword: "AUTH", arguments: args)
    }

    /// [SELECT](https://redis.io/commands/select)
    /// - Parameter index: The 0-based index of the database that the connection that sends this command will execute later commands against.
    public static func select(database index: Int) -> RedisCommand<Void> {
        let args = [RESPValue(bulk: index)]
        return .init(keyword: "SELECT", arguments: args)
    }
}

// MARK: -

extension RedisClient {
    /// Pings the server, which will respond with a message.
    ///
    /// See ``RedisCommand/ping(with:)``
    /// - Parameters:
    ///     - message: The optional message that the server should respond with instead of the default.
    ///     - eventLoop: An optional event loop to hop to for any further chaining on the returned event loop future.
    ///     - logger: An optional logger instance to use for logs generated from this command.
    /// - Returns: A `NIO.EventLoopFuture` that resolves the given `message` or Redis' default response of `PONG`.
    public func ping(
        with message: String? = nil,
        eventLoop: EventLoop? = nil,
        logger: Logger? = nil
    ) -> EventLoopFuture<String> {
        return self.send(.ping(with: message), eventLoop: eventLoop, logger: logger)
    }

    /// Requests the client to authenticate with Redis to allow other commands to be executed.
    ///
    /// See ``RedisCommand/auth(with:)``
    /// - Parameters:
    ///     - password: The password to authenticate with.
    ///     - eventLoop: An optional event loop to hop to for any further chaining on the returned event loop future.
    ///     - logger: An optional logger instance to use for logs generated from this command.
    /// - Returns: A `NIO.EventLoopFuture` that resolves if the password as accepted, otherwise it fails.
    public func authorize(
        with password: String,
        eventLoop: EventLoop? = nil,
        logger: Logger? = nil
    ) -> EventLoopFuture<Void> {
        return self.send(.auth(with: password), eventLoop: eventLoop, logger: logger)
    }

    /// Selects the Redis logical database having the given zero-based numeric index.
    ///
    /// See ``RedisCommand/select(database:)``
    /// - Note: New connections always use the database `0`.
    /// - Parameters:
    ///     - index: The 0-based index of the database that the connection sending this command will execute later commands against.
    ///     - eventLoop: An optional event loop to hop to for any further chaining on the returned event loop future.
    ///     - logger: An optional logger instance to use for logs generated from this command.
    /// - Returns: A `NIO.EventLoopFuture` resolving once the operation has succeeded.
    public func select(
        database index: Int,
        eventLoop: EventLoop? = nil,
        logger: Logger? = nil
    ) -> EventLoopFuture<Void> {
        return self.send(.select(database: index), eventLoop: eventLoop, logger: logger)
    }
}
