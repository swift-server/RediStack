//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2020 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Logging
import NIO

/// The system funnel for all `Logging` static details such as labels, `Logging.Logger` prototypes, and metadata keys used by RediStack.
public enum RedisLogging {
    /// The label values used in RediStack for `Logging.Logger` instances.
    public struct Labels {
        public static var connection: String { "RediStack.RedisConnection" }
        public static var connectionPool: String { "RediStack.RedisConnectionPool" }
    }
    /// The key values used in RediStack for storing `Logging.Logger.Metadata` in log messages.
    ///
    /// Only keys used in logs of `Logging.Logger.LogLevel` `.info` or higher are provided.
    public struct MetadataKeys {
        // All public keys should be prefixed with `rdstk` unless there is prior art to not do so (such as 'error')
        // each key should also be 16 or less characters, as to avoid heap allocations which are expensive in the context
        // of Logging Metadata
        
        /// An error that has been tracked.
        public static var error: String { "error" }
        /// The ID of the connection that generated the log.
        public static var connectionID: String { "rdstk_conn_id" }
        /// The ID of the connection pool that generated the log, or owns the connection that generated the log.
        public static var connectionPoolID: String { "rdstk_conpool_id" }
        /// The list of address(es) that a given pool is now targeting.
        public static var newConnectionPoolTargetAddresses: String { "rdstk_addresses" }

        // Internal keys can be as long as they want, but still should have the `rdstk` prefix to avoid clashes

        internal static var commandKeyword: String { "rdstk_command" }
        internal static var commandArguments: String { "rdstk_args" }
        internal static var commandResult: String { "rdstk_result" }
        internal static var connectionCount: String { "rdstk_conn_count" }
        internal static var poolConnectionRetryBackoff: String { "rdstk_conn_retry_prev_backoff" }
        internal static var poolConnectionRetryNewBackoff: String { "rdstk_conn_retry_new_backoff" }
        internal static var poolConnectionCount: String { "rdstk_pool_active_connection_count" }
        internal static let pubsubTarget = "rdstk_ps_target"
        internal static let subscriptionCount = "rdstk_sub_count"
    }
    
    public static let baseConnectionLogger = Logger(label: Labels.connection)
    public static let baseConnectionPoolLogger = Logger(label: Labels.connectionPool)
}

// MARK: Logger integration

extension Logger {
    /// The prototypical instance used for Redis connections.
    public static var redisBaseConnectionLogger: Logger { RedisLogging.baseConnectionLogger }
    /// The prototypical instance used for Redis connection pools.
    public static var redisBaseConnectionPoolLogger: Logger { RedisLogging.baseConnectionPoolLogger }
}

// MARK: Protocol-based Context Passing

/// An internal protocol for any `RedisClient` to conform to in order to use a user's execution context for the lifetime of a command.
///
/// An execution context includes things like a `Logging.Logger` instance for command activity logs.
internal protocol RedisClientWithUserContext: RedisClient {
    func send(command: String, with arguments: [RESPValue], context: Context?) -> EventLoopFuture<RESPValue>

    func subscribe(
        to channels: [RedisChannelName],
        messageReceiver receiver: @escaping RedisSubscriptionMessageReceiver,
        onSubscribe subscribeHandler: RedisSubscriptionChangeHandler?,
        onUnsubscribe unsubscribeHandler: RedisSubscriptionChangeHandler?,
        context: Context?
    ) -> EventLoopFuture<Void>
    func unsubscribe(from channels: [RedisChannelName], context: Context?) -> EventLoopFuture<Void>

    func psubscribe(
        to patterns: [String],
        messageReceiver receiver: @escaping RedisSubscriptionMessageReceiver,
        onSubscribe subscribeHandler: RedisSubscriptionChangeHandler?,
        onUnsubscribe unsubscribeHandler: RedisSubscriptionChangeHandler?,
        context: Context?
    ) -> EventLoopFuture<Void>
    func punsubscribe(from patterns: [String], context: Context?) -> EventLoopFuture<Void>
}

/// An internal implementation wrapper of a given `RedisClientWithUserContext` that enables users to pass a given `Logging.Logger`
/// instance to capture command logs within their preferred contexts.
internal struct UserContextRedisClient<Client: RedisClientWithUserContext>: RedisClient {
    internal var eventLoop: EventLoop { self.client.eventLoop }
    
    private let client: Client
    internal let context: Context
    
    internal init(client: Client, context: Context) {
        self.client = client
        self.context = context
    }
    
    // Create a new instance of the custom logging implementation reusing the same client.
    
    internal func logging(to logger: Logger) -> RedisClient {
        return UserContextRedisClient(client: self.client, context: logger)
    }
    
    // Forward the commands to the underlying client
    
    internal func send(command: String, with arguments: [RESPValue]) -> EventLoopFuture<RESPValue> {
        return self.eventLoop.flatSubmit {
            return self.client.send(command: command, with: arguments, context: self.context)
        }
    }
    
    internal func unsubscribe(from channels: [RedisChannelName]) -> EventLoopFuture<Void> {
        return self.eventLoop.flatSubmit { self.client.unsubscribe(from: channels, context: self.context) }
    }
    
    internal func punsubscribe(from patterns: [String]) -> EventLoopFuture<Void> {
        return self.eventLoop.flatSubmit { self.client.punsubscribe(from: patterns, context: self.context) }
    }

    internal func subscribe(
        to channels: [RedisChannelName],
        messageReceiver receiver: @escaping RedisSubscriptionMessageReceiver,
        onSubscribe subscribeHandler: RedisSubscriptionChangeHandler?,
        onUnsubscribe unsubscribeHandler: RedisSubscriptionChangeHandler?
    ) -> EventLoopFuture<Void> {
        return self.eventLoop.flatSubmit {
            self.client.subscribe(
                to: channels,
                messageReceiver: receiver,
                onSubscribe: subscribeHandler,
                onUnsubscribe: unsubscribeHandler,
                context: self.context
            )
        }
    }
    
    internal func psubscribe(
        to patterns: [String],
        messageReceiver receiver: @escaping RedisSubscriptionMessageReceiver,
        onSubscribe subscribeHandler: RedisSubscriptionChangeHandler?,
        onUnsubscribe unsubscribeHandler: RedisSubscriptionChangeHandler?
    ) -> EventLoopFuture<Void> {
        return self.eventLoop.flatSubmit {
            self.client.psubscribe(
                to: patterns,
                messageReceiver: receiver,
                onSubscribe: subscribeHandler,
                onUnsubscribe: unsubscribeHandler,
                context: self.context
            )
        }
    }
}
