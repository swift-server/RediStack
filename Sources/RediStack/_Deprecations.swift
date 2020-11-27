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

extension RedisConnection {
    /// The documented default port that Redis connects through.
    ///
    /// See [https://redis.io/topics/quickstart](https://redis.io/topics/quickstart)
    @available(*, deprecated, message: "Use RedisConnection.Configuration.defaultPort")
    public static var defaultPort: Int { Configuration.defaultPort }

    /// Creates a new connection to a Redis instance.
    ///
    /// If you would like to specialize the `NIO.ClientBootstrap` that the connection communicates on, override the default by passing it in as `tcpClient`.
    ///
    ///     let eventLoopGroup: EventLoopGroup = ...
    ///     var customTCPClient = ClientBootstrap.makeRedisTCPClient(group: eventLoopGroup)
    ///     customTCPClient.channelInitializer { channel in
    ///         // channel customizations
    ///     }
    ///     let connection = RedisConnection.connect(
    ///         to: ...,
    ///         on: eventLoopGroup.next(),
    ///         password: ...,
    ///         tcpClient: customTCPClient
    ///     ).wait()
    ///
    /// It is recommended that you be familiar with `ClientBootstrap.makeRedisTCPClient(group:)` and `NIO.ClientBootstrap` in general before doing so.
    ///
    /// Note: Use of `wait()` in the example is for simplicity. Never call `wait()` on an event loop.
    ///
    /// - Important: Call `close()` on the connection before letting the instance deinit to properly cleanup resources.
    /// - Note: If a `password` is provided, the connection will send an "AUTH" command to Redis as soon as it has been opened.
    ///
    /// - Parameters:
    ///     - socket: The `NIO.SocketAddress` information of the Redis instance to connect to.
    ///     - eventLoop: The `NIO.EventLoop` that this connection will execute all tasks on.
    ///     - password: The optional password to use for authorizing the connection with Redis.
    ///     - logger: The `Logging.Logger` instance to use for all client logging purposes. If one is not provided, one will be created.
    ///         A `Foundation.UUID` will be attached to the metadata to uniquely identify this connection instance's logs.
    ///     - tcpClient: If you have chosen to configure a `NIO.ClientBootstrap` yourself, this will be used instead of the `makeRedisTCPClient` instance.
    /// - Returns: A `NIO.EventLoopFuture` that resolves with the new connection after it has been opened, and if a `password` is provided, authenticated.
    @available(*, deprecated, message: "Use make(configuration:boundEventLoop:configuredTCPClient:) instead")
    public static func connect(
        to socket: SocketAddress,
        on eventLoop: EventLoop,
        password: String? = nil,
        logger: Logger = .redisBaseConnectionLogger,
        tcpClient: ClientBootstrap? = nil
    ) -> EventLoopFuture<RedisConnection> {
        let config: Configuration
        do {
            config = try .init(
                address: socket,
                password: password,
                defaultLogger: logger
            )
        } catch {
            return eventLoop.makeFailedFuture(error)
        }
        
        return self.make(configuration: config, boundEventLoop: eventLoop, configuredTCPClient: tcpClient)
    }
}

extension RedisConnectionPool {
    /// Create a new `RedisConnectionPool`.
    ///
    /// - parameters:
    ///     - serverConnectionAddresses: The set of Redis servers to which this pool is initially willing to connect.
    ///         This set can be updated over time.
    ///     - loop: The event loop to which this pooled client is tied.
    ///     - maximumConnectionCount: The maximum number of connections to for this pool, either to be preserved or as a hard limit.
    ///     - minimumConnectionCount: The minimum number of connections to preserve in the pool. If the pool is mostly idle
    ///         and the Redis servers close these idle connections, the `RedisConnectionPool` will initiate new outbound
    ///         connections proactively to avoid the number of available connections dropping below this number. Defaults to `1`.
    ///     - connectionPassword: The password to use to connect to the Redis servers in this pool.
    ///     - connectionLogger: The `Logger` to pass to each connection in the pool.
    ///     - connectionTCPClient: The base `ClientBootstrap` to use to create pool connections, if a custom one is in use.
    ///     - poolLogger: The `Logger` used by the connection pool itself.
    ///     - connectionBackoffFactor: Used when connection attempts fail to control the exponential backoff. This is a multiplicative
    ///         factor, each connection attempt will be delayed by this amount times the previous delay.
    ///     - initialConnectionBackoffDelay: If a TCP connection attempt fails, this is the first backoff value on the reconnection attempt.
    ///         Subsequent backoffs are computed by compounding this value by `connectionBackoffFactor`.
    ///     - connectionRetryTimeout: The max time to wait for a connection to be available before failing a particular command or connection operation.
    ///         The default is 60 seconds.
    @available(*, deprecated, message: "Use .init(configuration:boundEventLoop:) instead.")
    public convenience init(
        serverConnectionAddresses: [SocketAddress],
        loop: EventLoop,
        maximumConnectionCount: RedisConnectionPoolSize,
        minimumConnectionCount: Int = 1,
        connectionPassword: String? = nil, // config
        connectionLogger: Logger = .redisBaseConnectionLogger, // config
        connectionTCPClient: ClientBootstrap? = nil,
        poolLogger: Logger = .redisBaseConnectionPoolLogger,
        connectionBackoffFactor: Float32 = 2,
        initialConnectionBackoffDelay: TimeAmount = .milliseconds(100),
        connectionRetryTimeout: TimeAmount? = .seconds(60)
    ) {
        self.init(
            configuration: Configuration(
                initialServerConnectionAddresses: serverConnectionAddresses,
                maximumConnectionCount: maximumConnectionCount,
                connectionFactoryConfiguration: ConnectionFactoryConfiguration(
                    connectionPassword: connectionPassword,
                    connectionDefaultLogger: connectionLogger,
                    tcpClient: connectionTCPClient
                ),
                minimumConnectionCount: minimumConnectionCount,
                connectionBackoffFactor: connectionBackoffFactor,
                initialConnectionBackoffDelay: initialConnectionBackoffDelay,
                connectionRetryTimeout: connectionRetryTimeout,
                poolDefaultLogger: poolLogger
            ),
            boundEventLoop: loop
        )
    }
}

// MARK: - RedisKeyLifetime
@available(*, deprecated, message: "renamed to RedisKey.Lifetime")
public typealias RedisKeyLifetime = RedisKey.Lifetime

extension RedisKey.Lifetime {
    @available(*, deprecated, message: "renamed to Duration")
    public typealias Lifetime = Duration
}
