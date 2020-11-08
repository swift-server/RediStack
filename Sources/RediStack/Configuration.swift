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

import Foundation
import Logging
import NIO

extension RedisConnection.Configuration {
    public struct ValidationError: LocalizedError, Equatable {
        public static let invalidURLString = ValidationError(.invalidURLString)
        public static let missingURLScheme = ValidationError(.missingURLScheme)
        public static let invalidURLScheme = ValidationError(.invalidURLScheme)
        public static let missingURLHost = ValidationError(.missingURLHost)
        public static let outOfBoundsDatabaseID = ValidationError(.outOfBoundsDatabaseID)

        var localizedDescription: String { self.kind.localizedDescription }

        private let kind: Kind
        
        private init(_ kind: Kind) { self.kind = kind }
        
        public static func ==(lhs: ValidationError, rhs: ValidationError) -> Bool {
            return lhs.kind == rhs.kind
        }
        
        private enum Kind: LocalizedError {
            case invalidURLString
            case missingURLScheme
            case invalidURLScheme
            case missingURLHost
            case outOfBoundsDatabaseID
            
            var localizedDescription: String {
                let message: String = {
                    switch self {
                    case .invalidURLString: return "invalid URL string"
                    case .missingURLScheme: return "URL scheme is missing"
                    case .invalidURLScheme: return "invalid URL scheme, expected 'redis'"
                    case .missingURLHost: return "missing remote hostname"
                    case .outOfBoundsDatabaseID: return "database index out of bounds"
                    }
                }()
                return "(RediStack) \(RedisConnection.Configuration.self) validation failed: \(message)"
            }
        }
    }
}

// MARK: - RedisConnection Config

extension RedisConnection {
    /// A configuration object for creating a single connection to Redis.
    public struct Configuration {
        /// The default port that Redis uses.
        ///
        /// See [https://redis.io/topics/quickstart](https://redis.io/topics/quickstart)
        public static var defaultPort = 6379
        
        internal static let defaultLogger = Logger.redisBaseConnectionLogger

        /// The hostname of the connection address. If the address is a Unix socket, then it will be `nil`.
        public var hostname: String? {
            switch self.address {
            case let .v4(addr): return addr.host
            case let .v6(addr): return addr.host
            case .unixDomainSocket: return nil
            }
        }
        /// The port of the connection address. If the address is a Unix socket, then it will be `nil`.
        public var port: Int? { self.address.port }
        /// The password used to authenticate the connection.
        public let password: String?
        /// The initial database index that the connection should use.
        public let initialDatabase: Int?
        /// The logger prototype that will be used by the connection by default when generating logs.
        public let defaultLogger: Logger
        
        internal let address: SocketAddress
        
        /// Creates a new connection configuration with the provided details.
        /// - Parameters:
        ///     - address: The socket address information to use for creating the Redis connection.
        ///     - password: The optional password to authenticate the connection with. The default is `nil`.
        ///     - initialDatabase: The optional database index to initially connect to. The default is `nil`.
        ///     Redis by default opens connections against index `0`, so only set this value if the desired default is not `0`.
        ///     - defaultLogger: The optional prototype logger to use as the default logger instance when generating logs from the connection.
        ///     If one is not provided, one will be generated. See `RedisLogging.baseConnectionLogger`.
        /// - Throws: `RedisConnection.Configuration.ValidationError` if invalid arguments are provided.
        public init(
            address: SocketAddress,
            password: String? = nil,
            initialDatabase: Int? = nil,
            defaultLogger: Logger? = nil
        ) throws {
            if initialDatabase != nil && initialDatabase! < 0 {
                throw ValidationError.outOfBoundsDatabaseID
            }
            
            self.address = address
            self.password = password
            self.initialDatabase = initialDatabase
            self.defaultLogger = defaultLogger ?? Configuration.defaultLogger
        }

        /// Creates a new connection configuration with exact details.
        /// - Parameters:
        ///     - hostname: The remote hostname to connect to.
        ///     - port: The port that the Redis instance connects with. The default is `RedisConnection.Configuration.defaultPort`.
        ///     - password: The optional password to authenticate the connection with. The default is `nil`.
        ///     - initialDatabase: The optional database index to initially connect to. The default is `nil`.
        ///     Redis by default opens connections against index `0`, so only set this value if the desired default is not `0`.
        ///     - defaultLogger: The optional prototype logger to use as the default logger instance when generating logs from the connection.
        ///     If one is not provided, one will be generated. See `RedisLogging.baseConnectionLogger`.
        /// - Throws:
        ///     - `NIO.SocketAddressError` if hostname resolution fails.
        ///     - `RedisConnection.Configuration.ValidationError` if invalid arguments are provided.
        public init(
            hostname: String,
            port: Int = Self.defaultPort,
            password: String? = nil,
            initialDatabase: Int? = nil,
            defaultLogger: Logger? = nil
        ) throws {
            try self.init(
                address: try .makeAddressResolvingHost(hostname, port: port),
                password: password,
                initialDatabase: initialDatabase,
                defaultLogger: defaultLogger
            )
        }

        /// Creates a new connection configuration from the provided RFC 1808 URL formatted string.
        ///
        /// This is a convenience initializer over creating a `Foundation.URL` directly and passing it to the overloaded initializer.
        ///
        /// The string is expected to match the [RFC 1808](https://tools.ietf.org/html/rfc1808) format.
        ///
        /// An example string:
        ///
        ///     redis://:password@localhost:6379/3
        ///
        /// For more details, see the `Configuration.init(url:)` overload that accepts a `Foundation.URL`.
        /// - Parameters:
        ///     - string: The URL formatted string.
        ///     - defaultLogger: The optional prototype logger to use as the default logger instance when generating logs from the connection.
        ///     If one is not provided, one will be generated. See `RedisLogging.baseConnectionLogger`.
        /// - Throws:
        ///     - `RedisConnection.Configuration.ValidationError` if required URL components are invalid or missing.
        ///     - `NIO.SocketAddressError` if hostname resolution fails.
        public init(url string: String, defaultLogger: Logger? = nil) throws {
            guard let url = URL(string: string) else { throw ValidationError.invalidURLString }
            try self.init(url: url, defaultLogger: defaultLogger)
        }

        /// Creates a new connection configuration from the provided URL object.
        ///
        /// The `scheme` and `host` are the only properties that need to be established.
        /// - Invariant: The `port` property is optional, with the `RedisConnection.Configuration.defaultPort` being used by default.
        /// - Invariant: `password` is only required if the Redis instance specifies a password is required. This will not be detected until trying to establish a connection
        /// with this configuration.
        /// - Invariant: To set the default selected database index, provide the index as the `lastPathComponent` of the `Foundation.URL`.
        /// - Requires: The URL **must** use the `redis://` scheme.
        /// - Parameters:
        ///     - url: The URL to use to resolve and authenticate the remote connection.
        ///     - defaultLogger: The optional prototype logger to use as the default logger instance when generating logs from the connection.
        ///     If one is not provided, one will be generated. See `RedisLogging.baseConnectionLogger`.
        /// - Throws:
        ///     - `RedisConnection.Configuration.ValidationError` if required URL components are invalid or missing.
        ///     - `NIO.SocketAddressError` if hostname resolution fails.
        public init(url: URL, defaultLogger: Logger? = nil) throws {
            try Self.validateRedisURL(url)

            guard let host = url.host, !host.isEmpty else { throw ValidationError.missingURLHost }
            
            let databaseID = Int(url.lastPathComponent)
            
            try self.init(
                address: try .makeAddressResolvingHost(host, port: url.port ?? Self.defaultPort),
                password: url.password,
                initialDatabase: databaseID,
                defaultLogger: defaultLogger
            )
        }

        private static func validateRedisURL(_ url: URL) throws {
            guard
                let scheme = url.scheme,
                !scheme.isEmpty
            else { throw ValidationError.missingURLScheme }

            guard scheme == "redis" else { throw ValidationError.invalidURLScheme }
        }
    }
}

// MARK: - RedisConnectionPool Config

extension RedisConnectionPool {
    /// A configuration object for creating Redis connections with a connection pool.
    /// - Warning: This type has **reference** semantics due to the `NIO.ClientBootstrap` reference.
    public struct ConnectionFactoryConfiguration {
        // this needs to be var so it can be updated by the pool with the pool id
        /// The logger prototype that will be used by connections by default when generating logs.
        public internal(set) var connectionDefaultLogger: Logger
        /// The password used to authenticate connections.
        public let connectionPassword: String?
        /// The initial database index that connections should use.
        public let connectionInitialDatabase: Int?
        /// The pre-configured TCP client for connections to use.
        public let tcpClient: ClientBootstrap?
    
        /// Creates a new connection factory configuration with the provided options.
        /// - Parameters:
        ///     - connectionInitialDatabase: The optional database index to initially connect to. The default is `nil`.
        ///     Redis by default opens connections against index `0`, so only set this value if the desired default is not `0`.
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
            self.connectionInitialDatabase = connectionInitialDatabase
            self.connectionPassword = connectionPassword
            self.connectionDefaultLogger = connectionDefaultLogger ?? RedisConnection.Configuration.defaultLogger
            self.tcpClient = tcpClient
        }
    }

    /// A configuration object for connection pools.
    /// - Warning: This type has **reference** semantics due to `ConnectionFactoryConfiguration`.
    public struct Configuration {
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
            connectionRetryTimeout: TimeAmount? = .seconds(60),
            poolDefaultLogger: Logger? = nil
        ) {
            self.initialConnectionAddresses = initialServerConnectionAddresses
            self.maximumConnectionCount = maximumConnectionCount
            self.factoryConfiguration = connectionFactoryConfiguration
            self.minimumConnectionCount = minimumConnectionCount
            self.connectionRetryConfiguration = (
                (initialConnectionBackoffDelay, connectionBackoffFactor),
                connectionRetryTimeout ?? .milliseconds(10) // always default to a baseline 10ms
            )
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
