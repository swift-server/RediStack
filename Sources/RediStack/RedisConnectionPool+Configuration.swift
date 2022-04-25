//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2022 RediStack project authors
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

// MARK: - Pool Connection Congfiguration

extension RedisConnectionPool {
    /// A configuration object for a connection pool to use when creating Redis connections.
    /// - Warning: This type has **reference** semantics due to the `NIO.ClientBootstrap` reference.
    public struct PoolConnectionConfiguration {
        // this needs to be var so it can be updated by the pool with the pool id
        /// The logger that will be used by connections by default when generating logs.
        public internal(set) var defaultLogger: Logger
        /// The password used to authenticate connections.
        public let password: String?
        /// The initial database index that connections should use.
        public let initialDatabase: Int?
        /// The pre-configured TCP client for connections to use.
        public let tcpClient: ClientBootstrap?

        /// Creates a new connection factory configuration with the provided options.
        /// - Parameters:
        ///     - initialDatabase: The optional database index to initially connect to. The default is `nil`.
        ///     Redis by default opens connections against index `0`, so only set this value if the desired default is not `0`.
        ///     - password: The optional password to authenticate connections with. The default is `nil`.
        ///     - defaultLogger: The optional prototype logger to use as the default logger instance when generating logs from connections.
        ///     If one is not provided, one will be generated. See ``RedisLogging/baseConnectionLogger``.
        ///     - tcpClient: If you have chosen to configure a `NIO.ClientBootstrap` yourself, this will be used instead of the `.makeRedisTCPClient` factory instance.
        public init(
            initialDatabase: Int? = nil,
            password: String? = nil,
            defaultLogger: Logger? = nil,
            tcpClient: ClientBootstrap? = nil
        ) {
            self.initialDatabase = initialDatabase
            self.password = password
            self.defaultLogger = defaultLogger ?? RedisConnection.Configuration.defaultLogger
            self.tcpClient = tcpClient
        }
    }
}

// MARK: - Connection Count Behavior

extension RedisConnectionPool {
    /// The desired behavior for a connection pool to maintain its pool of "active" (connecting, in-use, or pooled) connections.
    public struct ConnectionCountBehavior {
        /// The pool will allow no more than the specified maximum number of connections to be "active" at any given time.
        ///
        /// This will force possible future users of connections to wait until an "active" connection becomes available
        /// by being returned to the pool.
        ///
        /// In other words, this provides a hard upper limit on concurrency.
        /// - Parameters:
        ///     - maximumConnectionCount: The maximum number of connections to preserve in the pool.
        ///     - minimumConnectionCount: The minimum number of connections to preserve in the pool. The default is `1`.
        public static func strict(maximumConnectionCount: Int, minimumConnectionCount: Int = 1) -> Self {
            return .init(min: minimumConnectionCount, max: maximumConnectionCount, behavior: .strict)
        }

        /// The pool will maintain the specified number of maxiumum connections,
        /// but will create more as needed based on demand.
        ///
        /// Connections created to meet demaind are treated as "extra" connections,
        /// and will not be preserved after demand has reached below the specified ``maximumConnectionCount``.
        ///
        /// In other words, this does not provide a hard upper bound on concurrency, but does provide an upper bound on low-level load.
        /// - Parameters:
        ///     - maximumConnectionCount: The maximum number of connections to preserve in the pool.
        ///     - minimumConnectionCount: The minimum number of connections to preserve in the pool. The default is `1`.
        public static func elastic(maximumConnectionCount: Int, minimumConnectionCount: Int = 1) -> Self {
            return .init(min: minimumConnectionCount, max: maximumConnectionCount, behavior: .elastic)
        }

        /// Is the pool's maxiumum connection count elastic, allowing for additional on-demand connections?
        public var isElastic: Bool { self.maxConnectionBehavior == .elastic }

        /// The minimum number of connections to preserve in the pool.
        ///
        /// If the pool is mostly idle and the Redis servers close these idle connections,
        /// the ``RedisConnectionPool`` will initiate new outbound connections proactively
        /// to avoid the number of available connections dropping below this number.
        public let minimumConnectionCount: Int
        /// The maximum number of connections to preserve in the pool.
        ///
        /// The actual maximum number of connections created by a pool could exceed this value,
        /// based on if the behavior ``isElastic``.
        public let maximumConnectionCount: Int

        internal let maxConnectionBehavior: MaxConnectionBehavior
        internal enum MaxConnectionBehavior {
            case strict
            case elastic
        }

        private init(min: Int, max: Int, behavior: MaxConnectionBehavior) {

            self.minimumConnectionCount = min
            self.maximumConnectionCount = max
            self.maxConnectionBehavior = behavior
        }
    }
}

// MARK: - Connection Retry Strategy

extension TimeAmount {
    fileprivate static var minimumTimeoutTolerance: Self { .milliseconds(10) }
}

extension RedisConnectionPool {
    /// A definition of how a given connection pool will attempt to retry fulfilling requests for connections.
    ///
    /// Each strategy defines an ``initialDelay`` that will be waited before asking again for a connection.
    ///
    /// After that `initialDelay`, then the strategy's ``DeadlineProvider`` will be called
    /// to provide a new delay value to wait.
    ///
    /// The strategy will continue to execute to fulfill a connection request until either
    /// the ``timeout`` is reached or a connection is made available.
    /// - Important: All `timeout` values are clamped to a minimum tolerance level to avoid false negative timeouts,
    /// as there is a slight overhead to the connection pool's logic for finding available connections.
    public struct PoolConnectionRetryStrategy {
        /// A closure that receives the current retry delay and returns a new delay value to wait.
        public typealias DeadlineProvider = (TimeAmount) -> TimeAmount

        /// The default timeout strategies will use. The value is `.seconds(60)`.
        public static var defaultTimeout: TimeAmount { .seconds(60) }

        /// Requests for a connection from a pool will exponentially backoff polling the pool, or timeout.
        /// - Parameters:
        ///     - initialDelay: The initial delay of further retries. The default is `.milliseconds(100)`.
        ///     - backoffFactor: The factor to multiply the current backoff amount by when additional retries are made. The default is `2`.
        ///     - timeout: The maximum amount of time to wait before retrying ends. The default is ``defaultTimeout``.
        public static func exponentialBackoff(
            initialDelay: TimeAmount = .milliseconds(100),
            backoffFactor: Float32 = 2,
            timeout: TimeAmount = Self.defaultTimeout
        ) -> Self {
            return .init(
                initialDelay: initialDelay,
                timeout: timeout,
                { return .nanoseconds(Int64(Float32($0.nanoseconds) * backoffFactor)) }
            )
        }

        /// No retrying will occur. Requests for a connection will fail immediately if a connection is not available.
        public static var none: Self { return .none(timeout: .minimumTimeoutTolerance) }

        /// No retrying will occur. Requests for a connection will fail if a connection
        /// is not available after the specified timeout.
        /// - Parameter timeout: The maximum amount of time to wait before failing requests for a connection.
        public static func none(timeout: TimeAmount) -> Self {
            return .init(initialDelay: .zero, timeout: timeout, { _ in .zero })
        }

        public let initialDelay: TimeAmount
        public let timeout: TimeAmount
        private let deadlineProvider: DeadlineProvider

        /// Creates a strategy with a given initial delay value, a closure to calculate future delay values,
        /// and a timeout to provide an upper limit on waiting.
        /// - Parameters:
        ///     - initialDelay: The initial time to wait before retrying.
        ///     - timeout: The total time to wait before failing the request for a connection and cancelling retrying.
        ///
        ///         The value provided is clamped to a minimum tolerance level to avoid false negative timeouts,
        ///         as there is a slight overhead to the connection pool's logic for finding available connections.
        ///     - deadlineProvider: A method of calulating new delay values, given the current delay.
        public init(
            initialDelay: TimeAmount,
            timeout: TimeAmount = Self.defaultTimeout,
            _ deadlineProvider: @escaping DeadlineProvider
        ) {
            self.initialDelay = initialDelay
            // because there's some overhead in the connection pooling logic,
            // we want a baseline minimum tolerance so we don't always have false immediate timeouts
            self.timeout = timeout <= .minimumTimeoutTolerance ? .minimumTimeoutTolerance : timeout
            self.deadlineProvider = deadlineProvider
        }

        /// Determines the new delay amount to wait before the next retry attempt.
        /// - Parameter currentDelay: The current delay value that was waited before the current retry attempt.
        /// - Returns: A new delay value to wait before the next retry attempt.
        public func determineNewDelay(currentDelay: TimeAmount) -> TimeAmount {
            return self.deadlineProvider(currentDelay)
        }
    }
}

// MARK: - Pool Configuration

extension RedisConnectionPool {
    /// A configuration object for connection pools.
    /// - Warning: This type has **reference** semantics due to ``PoolConnectionConfiguration``.
    public struct Configuration {
        /// The set of Redis servers to which this pool is initially willing to connect.
        public let initialConnectionAddresses: [SocketAddress]
        /// The behavior the pool should use for maintaining its pool of "active" connections and providing connections upon request.
        public let connectionCountBehavior: ConnectionCountBehavior
        /// The strategy used by the connection pool to handle retrying to find an available "active" connection to use.
        public let retryStrategy: PoolConnectionRetryStrategy

        // these need to be var so they can be updated by the pool in some cases

        /// The configuration used when creating connections.
        public internal(set) var connectionConfiguration: PoolConnectionConfiguration
        /// The logger prototype that will be used by the connection pool by default when generating logs.
        public internal(set) var poolDefaultLogger: Logger

        /// Creates a new connection configuration with the provided options.
        /// - Parameters:
        ///     - initialServerConnectionAddresses: The set of Redis servers to which this pool is initially willing to connect.
        ///         This set can be updated over time directly on the connection pool.
        ///     - connectionCountBehavior: The behavior used by the pool for maintaining it's count of connections.
        ///     - connectionConfiguration: The configuration to use when creating connections to fill the pool.
        ///     - retryStrategy: The retry strategy to apply while waiting for connections to become available for a particular command or connection operation.
        ///
        ///         The default is ``RedisConnectionPool/PoolConnectionRetryStrategy/exponentialBackoff(initialDelay:backoffFactor:timeout:)`` with default values.
        ///     - poolDefaultLogger: The `Logger` used by the connection pool itself.
        public init(
            initialServerConnectionAddresses: [SocketAddress],
            connectionCountBehavior: ConnectionCountBehavior,
            connectionConfiguration: PoolConnectionConfiguration,
            retryStrategy: PoolConnectionRetryStrategy = .exponentialBackoff(),
            poolDefaultLogger: Logger? = nil
        ) {
            self.initialConnectionAddresses = initialServerConnectionAddresses
            self.connectionCountBehavior = connectionCountBehavior
            self.connectionConfiguration = connectionConfiguration
            self.retryStrategy = retryStrategy
            self.poolDefaultLogger = poolDefaultLogger ?? .redisBaseConnectionPoolLogger
        }
    }
}
