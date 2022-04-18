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

import Logging
import NIO

/// The system funnel for all `Logging` static details such as labels, `Logging.Logger` prototypes, and metadata keys used by RediStack.
public enum RedisLogging {
    /// The label values used in RediStack for `Logging.Logger` instances.
    public struct Labels {
        public static var connection: String { "RediStack.RedisConnection" }
        public static var connectionPool: String { "RediStack.RedisConnectionPool" }
        public static var serviceDiscovery: String { "RediStack.RedisServiceDiscoveryClient" }
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

        internal static var command: String { "rdstk_command" }
        internal static var commandResult: String { "rdstk_result" }
        internal static var connectionCount: String { "rdstk_conn_count" }
        internal static var poolConnectionRetryAmount: String { "rdstk_conn_retry_prev_amount" }
        internal static var poolConnectionRetryNewAmount: String { "rdstk_conn_retry_new_amount" }
        internal static var poolConnectionCount: String { "rdstk_pool_active_connection_count" }
        internal static let pubsubTarget = "rdstk_ps_target"
        internal static let subscriptionCount = "rdstk_sub_count"
    }
    
    public static let baseConnectionLogger = Logger(label: Labels.connection)
    public static let baseConnectionPoolLogger = Logger(label: Labels.connectionPool)
    public static let baseServiceDiscoveryLogger = Logger(label: Labels.serviceDiscovery)
}

// MARK: Logger integration

extension Logger {
    /// The prototypical instance used for Redis connections.
    public static var redisBaseConnectionLogger: Logger { RedisLogging.baseConnectionLogger }
    /// The prototypical instance used for Redis connection pools.
    public static var redisBaseConnectionPoolLogger: Logger { RedisLogging.baseConnectionPoolLogger }
}

// MARK: RedisClient Logger Overrides

/// This is an implementation detail of baseline RediStack RedisClients that stores a reference to an underlying
/// RedisClient and a given logger instance, which is used as a new default logger on all commands.
internal struct CustomLoggerRedisClient<Client: RedisClient>: RedisClient {
    internal var eventLoop: EventLoop { self.client.eventLoop }

    internal let defaultLogger: Logger

    private let client: Client

    internal init(defaultLogger: Logger, client: Client) {
        self.defaultLogger = defaultLogger
        self.client = client
    }

    // create a new instance by just reusing the same client and passing the new logger instance

    internal func logging(to logger: Logger) -> RedisClient {
        return Self(defaultLogger: logger, client: client)
    }

    // forward methods to the underlying client

    // in each case we need to explicitly create a logger variable using the provided logger argument, defaulting to
    // the default logger if the argument is nil, because if we do it inline, the compiler will deduce the type
    // as optional, allowing the (possibly) nil argument to pass through without providing the default logger in nil cases

    internal func send<CommandResult>(_ command: RedisCommand<CommandResult>, eventLoop: EventLoop?, logger: Logger?) -> EventLoopFuture<CommandResult> {
        let logger = logger ?? self.defaultLogger
        return self.client.send(command, eventLoop: eventLoop, logger: logger)
    }

    internal func unsubscribe(from channels: [RedisChannelName], eventLoop: EventLoop?, logger: Logger?) -> EventLoopFuture<Void> {
        let logger = logger ?? self.defaultLogger
        return self.client.unsubscribe(from: channels, eventLoop: eventLoop, logger: logger)
    }

    internal func punsubscribe(from patterns: [String], eventLoop: EventLoop?, logger: Logger?) -> EventLoopFuture<Void> {
        let logger = logger ?? self.defaultLogger
        return self.client.punsubscribe(from: patterns, eventLoop: eventLoop, logger: logger)
    }

    internal func subscribe(to channels: [RedisChannelName], eventLoop: EventLoop?, logger: Logger?, messageReceiver receiver: @escaping RedisSubscriptionMessageReceiver, onSubscribe subscribeHandler: RedisSubscribeHandler?, onUnsubscribe unsubscribeHandler: RedisUnsubscribeHandler?) -> EventLoopFuture<Void> {
        let logger = logger ?? self.defaultLogger
        return self.client.subscribe(to: channels, eventLoop: eventLoop, logger: logger, messageReceiver: receiver, onSubscribe: subscribeHandler, onUnsubscribe: unsubscribeHandler)
    }

    internal func psubscribe(to patterns: [String], eventLoop: EventLoop?, logger: Logger?, messageReceiver receiver: @escaping RedisSubscriptionMessageReceiver, onSubscribe subscribeHandler: RedisSubscribeHandler?, onUnsubscribe unsubscribeHandler: RedisUnsubscribeHandler?) -> EventLoopFuture<Void> {
        let logger = logger ?? self.defaultLogger
        return self.client.psubscribe(to: patterns, eventLoop: eventLoop, logger: logger, messageReceiver: receiver, onSubscribe: subscribeHandler, onUnsubscribe: unsubscribeHandler)
    }
}
