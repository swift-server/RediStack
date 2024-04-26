//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2020-2023 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOCore
import NIOPosix
import Logging

extension RedisConnectionPool {
    /// A configuration object for creating Redis connections with a connection pool.
    /// - Warning: This type has **reference** semantics due to the `NIO.ClientBootstrap` reference.
    public struct ConnectionFactoryConfiguration {
        // this needs to be var so it can be updated by the pool with the pool id
        /// The logger prototype that will be used by connections by default when generating logs.
        public internal(set) var connectionDefaultLogger: Logger
        /// The username used to authenticate connections.
        /// - Warning: This property should only be provided if you are running against Redis 6 or higher.
        public let connectionUsername: String?
        /// The password used to authenticate connections.
        public let connectionPassword: String?
        /// The initial database index that connections should use.
        public let connectionInitialDatabase: Int?
        /// The pre-configured TCP client for connections to use.
        public let tcpClient: ClientBootstrap?

        /// Creates a new connection factory configuration with the provided options.
        /// - Parameters:
        ///     - connectionInitialDatabase: The optional database index to initially connect to. The default is `nil`.
        ///       Redis by default opens connections against index `0`, so only set this value if the desired default is not `0`.
        ///     - connectionPassword: The optional password to authenticate connections with. The default is `nil`.
        ///     - connectionDefaultLogger: The optional prototype logger to use as the default logger instance when generating logs from connections.
        ///     If one is not provided, one will be generated. See `RedisLogging.baseConnectionLogger`.
        ///     - tcpClient: If you have chosen to configure a `NIO.ClientBootstrap` yourself, this will be used instead of the `.makeRedisTCPClient` factory instance.
        public init(
            connectionInitialDatabase: Int? = nil,
            connectionPassword: String? = nil,
            connectionDefaultLogger: Logger? = nil,
            tcpClient: ClientBootstrap? = nil
        ) {
            self.init(
                connectionInitialDatabase: connectionInitialDatabase,
                connectionUsername: nil,
                connectionPassword: connectionPassword,
                connectionDefaultLogger: connectionDefaultLogger,
                tcpClient: tcpClient
            )
        }

        /// Creates a new connection factory configuration with the provided options.
        /// - Parameters:
        ///     - connectionInitialDatabase: The optional database index to initially connect to. The default is `nil`.
        ///       Redis by default opens connections against index `0`, so only set this value if the desired default is not `0`.
        ///     - connectionUsername: The optional username to authenticate connections with. The default is `nil`. Works only with Redis 6 and greater.
        ///     - connectionPassword: The optional password to authenticate connections with. The default is `nil`.
        ///     - connectionDefaultLogger: The optional prototype logger to use as the default logger instance when generating logs from connections.
        ///       If one is not provided, one will be generated. See `RedisLogging.baseConnectionLogger`.
        ///     - tcpClient: If you have chosen to configure a `NIO.ClientBootstrap` yourself, this will be used instead of the `.makeRedisTCPClient` factory instance.
        public init(
            connectionInitialDatabase: Int? = nil,
            connectionUsername: String? = nil,
            connectionPassword: String? = nil,
            connectionDefaultLogger: Logger? = nil,
            tcpClient: ClientBootstrap? = nil
        ) {
            self.connectionInitialDatabase = connectionInitialDatabase
            self.connectionUsername = connectionUsername
            self.connectionPassword = connectionPassword
            self.connectionDefaultLogger = connectionDefaultLogger ?? RedisConnection.Configuration.defaultLogger
            self.tcpClient = tcpClient
        }
    }

    /// A configuration object for connection pools.
    /// - Warning: This type has **reference** semantics due to `ConnectionFactoryConfiguration`.
    public struct Configuration {
        /// The default connection retry timeout
        public static let defaultConnectionRetryTimeout: TimeAmount = .seconds(60)
        /// The set of Redis servers to which this pool is initially willing to connect.
        public let initialConnectionAddresses: [SocketAddress]
        /// The minimum number of connections to preserve in the pool.
        ///
        /// If the pool is mostly idle and the Redis servers close these idle connections,
        /// the `RedisConnectionPool` will initiate new outbound connections proactively to avoid the number of available connections dropping below this number.
        public let minimumConnectionCount: Int
        /// The maximum number of connections to for this pool, either to be preserved or as a hard limit.
        public let maximumConnectionCount: RedisConnectionPoolSize
        /// The configuration object that controls the connection retry behavior.
        public let connectionRetryConfiguration: (backoff: (initialDelay: TimeAmount, factor: Float32), timeout: TimeAmount)
        /// Called when a connection in the pool is closed unexpectedly.
        public let onUnexpectedConnectionClose: ((RedisConnection) -> Void)?
        // these need to be var so they can be updated by the pool in some cases
        public internal(set) var factoryConfiguration: ConnectionFactoryConfiguration
        /// The logger prototype that will be used by the connection pool by default when generating logs.
        public internal(set) var poolDefaultLogger: Logger

        /// Creates a new connection configuration with the provided options.
        /// - Parameters:
        ///     - initialServerConnectionAddresses: The set of Redis servers to which this pool is initially willing to connect.
        ///         This set can be updated over time directly on the connection pool.
        ///     - maximumConnectionCount: The maximum number of connections to for this pool, either to be preserved or as a hard limit.
        ///     - connectionFactoryConfiguration: The configuration to use while creating connections to fill the pool.
        ///     - minimumConnectionCount: The minimum number of connections to preserve in the pool. If the pool is mostly idle
        ///         and the Redis servers close these idle connections, the `RedisConnectionPool` will initiate new outbound
        ///         connections proactively to avoid the number of available connections dropping below this number. Defaults to `1`.
        ///     - connectionBackoffFactor: Used when connection attempts fail to control the exponential backoff. This is a multiplicative
        ///         factor, each connection attempt will be delayed by this amount times the previous delay.
        ///     - initialConnectionBackoffDelay: If a TCP connection attempt fails, this is the first backoff value on the reconnection attempt.
        ///         Subsequent backoffs are computed by compounding this value by `connectionBackoffFactor`.
        ///     - connectionRetryTimeout: The max time to wait for a connection to be available before failing a particular command or connection operation.
        ///         The default is 60 seconds.
        ///     - poolDefaultLogger: The `Logger` used by the connection pool itself.
        public init(
            initialServerConnectionAddresses: [SocketAddress],
            maximumConnectionCount: RedisConnectionPoolSize,
            connectionFactoryConfiguration: ConnectionFactoryConfiguration,
            minimumConnectionCount: Int = 1,
            connectionBackoffFactor: Float32 = 2,
            initialConnectionBackoffDelay: TimeAmount = .milliseconds(100),
            connectionRetryTimeout: TimeAmount? = defaultConnectionRetryTimeout,
            onUnexpectedConnectionClose: ((RedisConnection) -> Void)? = nil,
            poolDefaultLogger: Logger? = nil
        ) {
            self.initialConnectionAddresses = initialServerConnectionAddresses
            self.maximumConnectionCount = maximumConnectionCount
            self.factoryConfiguration = connectionFactoryConfiguration
            self.minimumConnectionCount = minimumConnectionCount
            self.connectionRetryConfiguration = (
                (initialConnectionBackoffDelay, connectionBackoffFactor),
                connectionRetryTimeout ?? Self.defaultConnectionRetryTimeout
            )
            self.onUnexpectedConnectionClose = onUnexpectedConnectionClose
            self.poolDefaultLogger = poolDefaultLogger ?? .redisBaseConnectionPoolLogger
        }
    }
}

/// `RedisConnectionPoolSize` controls how the maximum number of connections in a pool are interpreted.
public enum RedisConnectionPoolSize {
    /// The pool will allow no more than this number of connections to be "active" (that is, connecting, in-use,
    /// or pooled) at any one time. This will force possible future users of new connections to wait until a currently
    /// active connection becomes available by being returned to the pool, but provides a hard upper limit on concurrency.
    case maximumActiveConnections(Int)

    /// The pool will only store up to this number of connections that are not currently in-use. However, if the pool is
    /// asked for more connections at one time than this number, it will create new connections to serve those waiting for
    /// connections. These "extra" connections will not be preserved: while they will be used to satisfy those waiting for new
    /// connections if needed, they will not be preserved in the pool if load drops low enough. This does not provide a hard
    /// upper bound on concurrency, but does provide an upper bound on low-level load.
    case maximumPreservedConnections(Int)
}
