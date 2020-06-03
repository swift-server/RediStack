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
    // This needs to be var because we hand it a closure that references us strongly. This also
    // establishes a reference cycle which we need to break.
    // Aside from on init, all other operations on this var must occur on the event loop.
    private var pool: ConnectionPool?

    /// This needs to be var because it is updatable and mutable. As a result, aside from init,
    /// all use of this var must occur on the event loop.
    private var serverConnectionAddresses: ConnectionAddresses

    private let loop: EventLoop

    private var poolLogger: Logger

    /// This lock exists only to access the pool logger. We don't use the pool logger here at all, but
    /// we need to be able to give it to users in a way that is thread-safe, as users can also set it from
    /// any thread they want.
    private let poolLoggerLock: Lock

    private let connectionPassword: String?

    private let connectionLogger: Logger

    private let connectionTCPClient: ClientBootstrap?

    private let poolID: UUID

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
        connectionLogger: Logger = .init(label: "RediStack.RedisConnection"),
        connectionTCPClient: ClientBootstrap? = nil,
        poolLogger: Logger = .init(label: "RediStack.RedisConnectionPool"),
        connectionBackoffFactor: Float32 = 2,
        initialConnectionBackoffDelay: TimeAmount = .milliseconds(100)
    ) {
        self.poolID = UUID()
        self.loop = loop
        self.serverConnectionAddresses = ConnectionAddresses(initialAddresses: serverConnectionAddresses)
        self.connectionPassword = connectionPassword

        var connectionLogger = connectionLogger
        connectionLogger[metadataKey: String(describing: RedisConnectionPool.self)] = "\(self.poolID)"
        self.connectionLogger = connectionLogger

        var poolLogger = poolLogger
        poolLogger[metadataKey: String(describing: RedisConnectionPool.self)] = "\(self.poolID)"
        self.poolLogger = poolLogger

        self.connectionTCPClient = connectionTCPClient
        self.poolLoggerLock = Lock()

        self.pool = ConnectionPool(
            maximumConnectionCount: maximumConnectionCount.size,
            minimumConnectionCount: minimumConnectionCount,
            leaky: maximumConnectionCount.leaky,
            loop: loop,
            logger: poolLogger,
            connectionBackoffFactor: connectionBackoffFactor,
            initialConnectionBackoffDelay: initialConnectionBackoffDelay,
            connectionFactory: self.connectionFactory(_:)
        )
    }
}

// MARK: General helpers.
extension RedisConnectionPool {
    public func activate() {
        self.loop.execute {
            self.pool?.activate()
        }
    }

    public func close() {
        self.loop.execute {
            self.pool?.close()

            // This breaks the cycle between us and the pool.
            self.pool = nil
        }
    }

    /// Updates the list of valid connection addresses.
    ///
    /// This does not invalidate existing connections: as long as those connections continue to stay up, they will be kept by
    /// this client. However, no new connections will be made to any endpoint that is not in `newTargets`.
    public func updateConnectionAddresses(_ newAddresses: [SocketAddress]) {
        self.poolLoggerLock.withLockVoid {
            self.poolLogger.info("Updated pool with new addresses", metadata: ["new-addresses": "\(newAddresses)"])
        }
        
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
            logger: self.connectionLogger,
            tcpClient: self.connectionTCPClient
        )
    }
}

// MARK: RedisClient conformance
extension RedisConnectionPool: RedisClient {
    public var eventLoop: EventLoop {
        return self.loop
    }

    public var logger: Logger {
        return self.poolLoggerLock.withLock {
            return self.poolLogger
        }
    }

    public func setLogging(to logger: Logger) {
        var logger = logger
        logger[metadataKey: String(describing: RedisConnectionPool.self)] = "\(self.poolID)"

        self.poolLoggerLock.withLock {
            self.poolLogger = logger

            // We must enqueue this before we drop the lock to prevent a race on setting this logger.
            self.loop.execute {
                self.pool?.setLogger(logger)
            }
        }
    }

    public func send(command: String, with arguments: [RESPValue]) -> EventLoopFuture<RESPValue> {
        // Establish event loop context then jump to the in-loop version.
        return self.loop.flatSubmit {
            return self._send(command: command, with: arguments)
        }
    }

    private func _send(command: String, with arguments: [RESPValue]) -> EventLoopFuture<RESPValue> {
        self.loop.preconditionInEventLoop()

        guard let pool = self.pool else {
            return self.loop.makeFailedFuture(RedisConnectionPoolError.poolClosed)
        }

        // For now we have to default the deadline. For maximum compatibility with the existing implementation, we use a fairly-long timeout:
        // one minute.
        return pool.leaseConnection(deadline: .now() + .seconds(60)).flatMap { connection in
            connection.sendCommandsImmediately = true
            return connection.send(command: command, with: arguments).always { _ in
                pool.returnConnection(connection)
            }
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
