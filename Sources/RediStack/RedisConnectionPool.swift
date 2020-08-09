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
import struct Foundation.UUID
import NIO
import NIOConcurrencyHelpers
import Logging

/// A `RedisConnectionPool` is an implementation of `RedisClient` backed by a pool of connections to Redis,
/// rather than a single one.
///
/// `RedisConnectionPool` uses a pool of connections on a single `EventLoop` to manage its activity. This
/// pool may vary in size and strategy, including how many active connections it tries to manage at any one
/// time and how it responds to demand for connections beyond its upper limit.
///
/// Note that `RedisConnectionPool` is entirely thread-safe, even though all of its connections belong to a
/// single `EventLoop`: if callers call the API from a different `EventLoop` (or from no `EventLoop` at all)
/// `RedisConnectionPool` will ensure that the call is dispatched to the correct loop.
public class RedisConnectionPool {
    /// A unique identifer to represent this connection.
    public let id = UUID()

    // This needs to be var because we hand it a closure that references us strongly. This also
    // establishes a reference cycle which we need to break.
    // Aside from on init, all other operations on this var must occur on the event loop.
    private var pool: ConnectionPool?

    /// This needs to be var because it is updatable and mutable. As a result, aside from init,
    /// all use of this var must occur on the event loop.
    private var serverConnectionAddresses: ConnectionAddresses

    private let connectionPassword: String?
    private let connectionSystemContext: Logger
    private let poolSystemContext: Context
    private let loop: EventLoop
    private let connectionTCPClient: ClientBootstrap?

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
    public init(
        serverConnectionAddresses: [SocketAddress],
        loop: EventLoop,
        maximumConnectionCount: RedisConnectionPoolSize,
        minimumConnectionCount: Int = 1,
        connectionPassword: String? = nil,
        connectionLogger: Logger = .redisBaseConnectionLogger,
        connectionTCPClient: ClientBootstrap? = nil,
        poolLogger: Logger = .redisBaseConnectionPoolLogger,
        connectionBackoffFactor: Float32 = 2,
        initialConnectionBackoffDelay: TimeAmount = .milliseconds(100)
    ) {
        self.loop = loop
        self.serverConnectionAddresses = ConnectionAddresses(initialAddresses: serverConnectionAddresses)
        self.connectionPassword = connectionPassword
        
        // mix of terminology here with the loggers
        // as we're being "forward thinking" in terms of the 'baggage context' future type

        var connectionLogger = connectionLogger
        connectionLogger[metadataKey: RedisLogging.MetadataKeys.connectionPoolID] = "\(self.id)"
        self.connectionSystemContext = connectionLogger

        var poolLogger = poolLogger
        poolLogger[metadataKey: RedisLogging.MetadataKeys.connectionPoolID] = "\(self.id)"
        self.poolSystemContext = poolLogger

        self.connectionTCPClient = connectionTCPClient

        self.pool = ConnectionPool(
            maximumConnectionCount: maximumConnectionCount.size,
            minimumConnectionCount: minimumConnectionCount,
            leaky: maximumConnectionCount.leaky,
            loop: loop,
            systemContext: poolLogger,
            connectionBackoffFactor: connectionBackoffFactor,
            initialConnectionBackoffDelay: initialConnectionBackoffDelay,
            connectionFactory: self.connectionFactory(_:)
        )
    }
}

// MARK: General helpers.
extension RedisConnectionPool {
    /// Starts the connection pool.
    ///
    /// This method is safe to call multiple times.
    /// - Parameter logger: An optional logger to use for any log statements generated while starting up the pool.
    ///         If one is not provided, the pool will use its default logger.
    public func activate(logger: Logger? = nil) {
        self.loop.execute {
            self.pool?.activate(logger: self.prepareLoggerForUse(logger))
        }
    }

    /// Closes all connections in the pool and deactivates the pool from creating new connections.
    ///
    /// This method is safe to call multiple times.
    /// - Important: If the pool has connections in active use, the close process will not complete.
    /// - Parameters:
    ///     - promise: A notification promise to resolve once the close process has completed.
    ///     - logger: An optional logger to use for any log statements generated while closing the pool.
    ///         If one is not provided, the pool will use its default logger.
    public func close(promise: EventLoopPromise<Void>? = nil, logger: Logger? = nil) {
        self.loop.execute {
            self.pool?.close(promise: promise, logger: self.prepareLoggerForUse(logger))

            // This breaks the cycle between us and the pool.
            self.pool = nil
        }
    }

    /// Updates the list of valid connection addresses.
    ///
    /// - Note: This does not invalidate existing connections: as long as those connections continue to stay up, they will be kept by
    /// this client.
    ///
    /// However, no new connections will be made to any endpoint that is not in `newAddresses`.
    /// - Parameters:
    ///     - newAddresses: The new addresses to connect to in future connections.
    ///     - logger: An optional logger to use for any log statements generated while updating the target addresses.
    ///         If one is not provided, the pool will use its default logger.
    public func updateConnectionAddresses(_ newAddresses: [SocketAddress], logger: Logger? = nil) {
        self.prepareLoggerForUse(logger)
            .info("pool updated with new target addresses", metadata: [
                RedisLogging.MetadataKeys.newConnectionPoolTargetAddresses: "\(newAddresses)"
            ])
        
        self.loop.execute {
            self.serverConnectionAddresses.update(newAddresses)
        }
    }

    private func connectionFactory(_ targetLoop: EventLoop) -> EventLoopFuture<RedisConnection> {
        // Validate the loop invariants.
        self.loop.preconditionInEventLoop()
        targetLoop.preconditionInEventLoop()

        guard let nextTarget = self.serverConnectionAddresses.nextTarget() else {
            // No valid connection target, we'll fail.
            return targetLoop.makeFailedFuture(RedisConnectionPoolError.noAvailableConnectionTargets)
        }

        return RedisConnection.connect(
            to: nextTarget,
            on: targetLoop,
            password: self.connectionPassword,
            logger: self.connectionSystemContext,
            tcpClient: self.connectionTCPClient
        )
    }

    private func prepareLoggerForUse(_ logger: Logger?) -> Logger {
        guard var logger = logger else { return self.poolSystemContext }
        logger[metadataKey: RedisLogging.MetadataKeys.connectionPoolID] = "\(self.id)"
        return logger
    }
}

// MARK: RedisClient conformance
extension RedisConnectionPool: RedisClient {
    public var eventLoop: EventLoop { self.loop }

    public func logging(to logger: Logger) -> RedisClient {
        return UserContextRedisClient(client: self, context: self.prepareLoggerForUse(logger))
    }

    public func send(command: String, with arguments: [RESPValue]) -> EventLoopFuture<RESPValue> {
        // Establish event loop context then jump to the in-loop version.
        return self.loop.flatSubmit {
            return self.send(command: command, with: arguments, context: nil)
        }
    }
}

// MARK: RedisClientWithUserContext conformance
extension RedisConnectionPool: RedisClientWithUserContext {
    internal func send(command: String, with arguments: [RESPValue], context: Logger?) -> EventLoopFuture<RESPValue> {
        self.loop.preconditionInEventLoop()

        guard let pool = self.pool else {
            return self.loop.makeFailedFuture(RedisConnectionPoolError.poolClosed)
        }

        let logger = self.prepareLoggerForUse(context)
        
        // For now we have to default the deadline.
        // For maximum compatibility with the existing implementation, we use a fairly-long timeout: one minute.
        return pool.leaseConnection(deadline: .now() + .seconds(60), logger: logger)
            .flatMap { connection in
                connection.sendCommandsImmediately = true
                return connection
                    .send(command: command, with: arguments, context: context)
                    .always { _ in pool.returnConnection(connection, logger: logger) }
            }
    }
}

// MARK: Helper for round-robin connection establishment
extension RedisConnectionPool {
    /// A helper structure for valid connection addresses. This structure implements round-robin connection establishment.
    private struct ConnectionAddresses {
        private var addresses: [SocketAddress]

        private var index: Array<SocketAddress>.Index

        init(initialAddresses: [SocketAddress]) {
            self.addresses = initialAddresses
            self.index = self.addresses.startIndex
        }

        mutating func nextTarget() -> SocketAddress? {
            // Early exit on 0, makes life easier.
            guard self.addresses.count > 0 else {
                self.index = self.addresses.startIndex
                return nil
            }

            // It's an invariant of this function that the index is always valid for subscripting the collection.
            let nextTarget = self.addresses[self.index]
            self.addresses.formIndex(after: &self.index)
            if self.index == self.addresses.endIndex {
                self.index = self.addresses.startIndex
            }
            return nextTarget
        }

        mutating func update(_ newAddresses: [SocketAddress]) {
            self.addresses = newAddresses
            self.index = self.addresses.startIndex
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

    internal var size: Int {
        switch self {
        case .maximumActiveConnections(let size), .maximumPreservedConnections(let size):
            return size
        }
    }

    internal var leaky: Bool {
        switch self {
        case .maximumActiveConnections:
            return false
        case .maximumPreservedConnections:
            return true
        }
    }
}
