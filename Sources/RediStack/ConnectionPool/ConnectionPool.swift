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

/// `ConnectionPool` is RediStack's internal representation of a pool of Redis connections.
///
/// `ConnectionPool` has two major jobs. Its first job is to reduce the latency cost of making a new Redis query by
/// keeping a number of connections active and warm. This improves the odds that any given attempt to make a query
/// will find an idle connection and avoid needing to create a new one.
///
/// The second job is to handle cluster management. In some cases there will be a cluster of Redis machines available,
/// any of which would be suitable for a query. The connection pool can be used to manage this cluster by automatically
/// spreading connection load across it.
///
/// In RediStack, each `ConnectionPool` is tied to a single event loop. All of its state may only be accessed from that
/// event loop. However, it does provide an API that is safe to call from any event loop. In latency sensitive applications,
/// it is a good idea to keep pools local to event loops. This can cause more connections to be made than if the pool was shared,
/// but it further reduces the latency cost of each database operation. In less latency sensitive applications, the pool can be
/// shared across all loops.
///
/// This `ConnectionPool` uses an MRU strategy for managing connections: the most recently used free connection is the one that
/// is used for a query. This system reduces the risk that a connection will die in the gap between being removed from the pool
/// and being used, at the cost of incurring more reconnects under low load. Of course, when we're under low load we don't
/// really care how many reconnects there are.
internal final class ConnectionPool {
    /// A function used to create Redis connections.
    private let connectionFactory: (EventLoop) -> EventLoopFuture<RedisConnection>

    /// A stack of connections that are active and suitable for use by clients.
    private(set) var availableConnections: ArraySlice<RedisConnection>

    /// A buffer of users waiting for connections to be handed over.
    private var connectionWaiters: CircularBuffer<Waiter>

    /// The event loop we're on.
    private let loop: EventLoop

    /// The strategy to use for finding and returning connections when requested.
    internal let connectionRetryStrategy: RedisConnectionPool.PoolConnectionRetryStrategy

    /// The minimum number of connections the pool will keep alive. If a connection is disconnected while in the
    /// pool such that the number of connections drops below this number, the connection will be re-established.
    internal let minimumConnectionCount: Int
    /// The maximum number of connections the pool will preserve.
    internal let maximumConnectionCount: Int
    /// The behavior to use for allowing or denying additional connections past the max connection count.
    internal let maxConnectionCountBehavior: RedisConnectionPool.ConnectionCountBehavior.MaxConnectionBehavior

    /// The number of connection attempts currently outstanding.
    private var pendingConnectionCount: Int
    /// The number of connections that have been handed out to users and are in active use.
    private(set) var leasedConnectionCount: Int

    /// The current state of this connection pool.
    private var state: State

    /// The number of connections that are "live": either in the pool, in the process of being created, or
    /// leased to users.
    private var activeConnectionCount: Int {
        return self.availableConnections.count + self.pendingConnectionCount + self.leasedConnectionCount
    }

    /// Whether a connection can be added into the availableConnections pool when it's returned.
    private var canAddConnectionToPool: Bool {
        switch self.maxConnectionCountBehavior {
        // only if the current available count is less than the max
        case .elastic:
            return self.availableConnections.count < self.maximumConnectionCount

        // only if the total connections count is less than the max
        case .strict:
            return (self.availableConnections.count + self.leasedConnectionCount) < self.maximumConnectionCount
        }
    }

    internal init(
        minimumConnectionCount: Int,
        maximumConnectionCount: Int,
        maxConnectionCountBehavior: RedisConnectionPool.ConnectionCountBehavior.MaxConnectionBehavior,
        connectionRetryStrategy: RedisConnectionPool.PoolConnectionRetryStrategy,
        loop: EventLoop,
        poolLogger: Logger,
        connectionFactory: @escaping (EventLoop) -> EventLoopFuture<RedisConnection>
    ) {
        self.minimumConnectionCount = minimumConnectionCount
        self.maximumConnectionCount = maximumConnectionCount
        self.maxConnectionCountBehavior = maxConnectionCountBehavior

        guard self.minimumConnectionCount <= self.maximumConnectionCount else {
            poolLogger.critical("pool's minimum connection count is higher than the maximum")
            preconditionFailure("minimum connection count must not exceed maximum")
        }

        self.pendingConnectionCount = 0
        self.leasedConnectionCount = 0
        self.availableConnections = []
        self.availableConnections.reserveCapacity(self.maximumConnectionCount)

        // 8 is a good number to skip the first few buffer resizings
        self.connectionWaiters = CircularBuffer(initialCapacity: 8)
        self.loop = loop
        self.connectionFactory = connectionFactory
        self.connectionRetryStrategy = connectionRetryStrategy

        self.state = .active
    }

    /// Activates this connection pool by causing it to populate its backlog of connections.
    func activate(logger: Logger) {
        if self.loop.inEventLoop {
            self.refillConnections(logger: logger)
        } else {
            self.loop.execute {
                self.refillConnections(logger: logger)
            }
        }
    }

    /// Deactivates this connection pool. Once this is called, no further connections can be obtained
    /// from the pool. Leased connections are not deactivated and can continue to be used.
    func close(promise: EventLoopPromise<Void>? = nil, logger: Logger) {
        if self.loop.inEventLoop {
            self.closePool(promise: promise, logger: logger)
        } else {
            self.loop.execute {
                self.closePool(promise: promise, logger: logger)
            }
        }
    }

    func leaseConnection(logger: Logger, deadline: NIODeadline? = nil) -> EventLoopFuture<RedisConnection> {
        let deadline = deadline ?? .now() + self.connectionRetryStrategy.timeout
        if self.loop.inEventLoop {
            return self._leaseConnection(logger: logger, deadline: deadline)
        } else {
            return self.loop.flatSubmit {
                return self._leaseConnection(logger: logger, deadline: deadline)
            }
        }
    }

    func returnConnection(_ connection: RedisConnection, logger: Logger) {
        if self.loop.inEventLoop {
            self._returnLeasedConnection(connection, logger: logger)
        } else {
            return self.loop.execute {
                self._returnLeasedConnection(connection, logger: logger)
            }
        }
    }
}

// MARK: Internal implementation
extension ConnectionPool {
    /// Ensures that sufficient connections are available in the pool.
    private func refillConnections(logger: Logger) {
        self.loop.assertInEventLoop()

        guard case .active = self.state else {
            // Don't do anything to refill connections if we're not in the active state: we don't care.
            return
        }

        var neededConnections = self.minimumConnectionCount - self.activeConnectionCount
        logger.trace("refilling connections", metadata: [
            RedisLogging.MetadataKeys.connectionCount: "\(neededConnections)"
        ])
        while neededConnections > 0 {
            self._createConnection(
                retryDelay: self.connectionRetryStrategy.initialDelay,
                startIn: .nanoseconds(0),
                logger: logger
            )
            neededConnections -= 1
        }
    }

    private func _createConnection(retryDelay: TimeAmount, startIn delay: TimeAmount, logger: Logger) {
        self.loop.assertInEventLoop()
        self.pendingConnectionCount += 1

        self.loop.scheduleTask(in: delay) {
            self.connectionFactory(self.loop)
                .whenComplete { result in
                    self.loop.preconditionInEventLoop()

                    self.pendingConnectionCount -= 1

                    switch result {
                    case .success(let connection):
                        self.connectionCreationSucceeded(connection, logger: logger)

                    case .failure(let error):
                        self.connectionCreationFailed(error, retryDelay: retryDelay, logger: logger)
                    }
                }
        }
    }

    private func connectionCreationSucceeded(_ connection: RedisConnection, logger: Logger) {
        self.loop.assertInEventLoop()
        
        logger.trace("connection creation succeeded", metadata: [
            RedisLogging.MetadataKeys.connectionID: "\(connection.id)"
        ])

        switch self.state {
        case .closing:
            // We don't want this anymore, drop it.
            _ = connection.close()
        case .closed:
            // This is programmer error, we shouldn't have entered this state.
            logger.critical("new connection created on a closed pool", metadata: [
                RedisLogging.MetadataKeys.connectionID: "\(connection.id)"
            ])
            preconditionFailure("In closed while pending connections were outstanding.")
        case .active:
            // Great, we want this. We'll be "returning" it to the pool. First,
            // attach the close callback to it.
            connection.channel.closeFuture.whenComplete { _ in self.poolConnectionClosed(connection, logger: logger) }
            self._returnConnection(connection, logger: logger)
        }
    }

    private func connectionCreationFailed(_ error: Error, retryDelay: TimeAmount, logger: Logger) {
        self.loop.assertInEventLoop()

        logger.warning("failed to create connection for pool", metadata: [
            RedisLogging.MetadataKeys.error: "\(error)"
        ])

        guard case .active = self.state else {
            // No point continuing connection creation if we're not active.
            logger.trace("not creating new connections due to inactivity")
            return
        }

        // Ok, we're still active. Before we do anything, we want to check whether anyone is still waiting
        // for this connection. Waiters can time out: if they do, we can just give up this connection.
        // We know folks need this in the following conditions:
        //
        // 1. For non-elastic buckets, we need this reconnection if there are any waiters AND the number of active connections (which includes
        //     pending connection attempts) is less than max connections
        // 2. For elastic buckets, we need this reconnection if connectionWaiters.count is greater than the number of pending connection attempts.
        // 3. For either kind, if the number of active connections is less than the minimum.
        let shouldReconnect: Bool
        switch self.maxConnectionCountBehavior {
        case .elastic:
            shouldReconnect = (self.connectionWaiters.count > self.pendingConnectionCount)
                || (self.minimumConnectionCount > self.activeConnectionCount)

        case .strict:
            shouldReconnect = (!self.connectionWaiters.isEmpty && self.maximumConnectionCount > self.activeConnectionCount)
                || (self.minimumConnectionCount > self.activeConnectionCount)
        }

        guard shouldReconnect else {
            logger.debug("not reconnecting due to sufficient existing connection attempts")
            return
        }

        // Ok, we need the new connection.
        let nextRetryDelay = self.connectionRetryStrategy.determineNewDelay(currentDelay: retryDelay)
        logger.debug("reconnecting after failed connection attempt", metadata: [
            RedisLogging.MetadataKeys.poolConnectionRetryAmount: "\(retryDelay)ns",
            RedisLogging.MetadataKeys.poolConnectionRetryNewAmount: "\(nextRetryDelay)ns"
        ])
        self._createConnection(retryDelay: nextRetryDelay, startIn: retryDelay, logger: logger)
    }

    /// A connection that was monitored by this pool has been closed.
    private func poolConnectionClosed(_ connection: RedisConnection, logger: Logger) {
        self.loop.preconditionInEventLoop()

        // We need to work out what kind of connection this was. This is easily done: if the connection is in the
        // availableConnections list then it's an available connection, otherwise it's a leased connection.
        // For leased connections we don't do any work here: those connections are required to be returned to the pool,
        // so we'll handle them when they come back.
        // We just do a linear scan here because the pool is rarely likely to be very large, so the cost of a fancier
        // datastructure is simply not worth it. Even the cost of shuffling elements around is low.
        if let index = self.availableConnections.firstIndex(where: { $0 === connection }) {
            // It's in the available set. Remove it.
            self.availableConnections.remove(at: index)
        }

        // We may need to refill connections to keep at our minimum connection count.
        self.refillConnections(logger: logger)
    }

    private func leaseConnection(_ connection: RedisConnection, to waiter: Waiter) {
        self.loop.assertInEventLoop()
        self.leasedConnectionCount += 1
        waiter.succeed(connection)
    }

    private func closePool(promise: EventLoopPromise<Void>?, logger: Logger) {
        self.loop.preconditionInEventLoop()

        // Pool closure must be monotonic.
        guard case .active = self.state else {
            logger.info("received duplicate request to close connection pool")
            promise?.succeed(())
            return
        }

        self.state = .closing

        // To close the pool we need to drop all active connections.
        let connections = self.availableConnections
        self.availableConnections = []
        let closeFutures = connections.map { $0.close() }

        // We also cancel all pending leases.
        while let pendingLease = self.connectionWaiters.popFirst() {
            pendingLease.fail(RedisConnectionPoolError.poolClosed)
        }

        guard self.activeConnectionCount == 0 else {
            logger.debug("not closing pool, waiting for all connections to be returned", metadata: [
                RedisLogging.MetadataKeys.poolConnectionCount: "\(self.activeConnectionCount)"
            ])
            promise?.fail(RedisConnectionPoolError.poolHasActiveConnections)
            return
        }

        // That was all the connections, so this is now closed.
        logger.trace("pool is now closed")
        self.state = .closed
        EventLoopFuture<Void>
            .andAllSucceed(closeFutures, on: self.loop)
            .cascade(to: promise)
    }

    /// This is the on-thread implementation for leasing connections out to users. Here we work out how to get a new
    /// connection, and attempt to do so.
    private func _leaseConnection(logger: Logger, deadline: NIODeadline) -> EventLoopFuture<RedisConnection> {
        self.loop.assertInEventLoop()

        guard case .active = self.state else {
            logger.trace("attempted to lease connection from closed pool")
            return self.loop.makeFailedFuture(RedisConnectionPoolError.poolClosed)
        }

        var waiter = Waiter(result: self.loop.makePromise())

        // Loop over the available connections. It's possible some of these are dead but we don't know
        // that yet, so double-check. Leave the dead ones there: we'll get them later.
        while let connection = self.availableConnections.popLast() {
            if connection.isConnected {
                logger.debug("found available connection", metadata: [
                    RedisLogging.MetadataKeys.connectionID: "\(connection.id)"
                ])
                self.leaseConnection(connection, to: waiter)
                return waiter.futureResult
            }
        }

        // Ok, we didn't have any available connections. We're going to have to wait. Set our timeout.
        waiter.scheduleDeadline(loop: self.loop, deadline: deadline) {
            logger.trace("connection not found in time")
            // The waiter timed out. We're going to fail the promise and remove the waiter.
            waiter.fail(RedisConnectionPoolError.timedOutWaitingForConnection)

            guard let index = self.connectionWaiters.firstIndex(where: { $0.id == waiter.id }) else { return }
            self.connectionWaiters.remove(at: index)
        }
        self.connectionWaiters.append(waiter)

        // Ok, we have connection targets. If the number of active connections is
        // below the max, or the pool is elastic, we can create a new connection. Otherwise, we just have
        // to wait for a connection to come back.

        let shouldCreateConnection: Bool
        switch self.maxConnectionCountBehavior {
        case .elastic: shouldCreateConnection = true
        case .strict: shouldCreateConnection = false
        }

        if self.activeConnectionCount < self.maximumConnectionCount || shouldCreateConnection {
            logger.trace("creating new connection")
            self._createConnection(
                retryDelay: self.connectionRetryStrategy.initialDelay,
                startIn: .nanoseconds(0),
                logger: logger
            )
        }

        return waiter.futureResult
    }

    /// This is the on-thread implementation for returning connections to the pool that were previously leased to users.
    /// It delegates to `_returnConnection`.
    private func _returnLeasedConnection(_ connection: RedisConnection, logger: Logger) {
        self.loop.assertInEventLoop()
        self.leasedConnectionCount -= 1
        self._returnConnection(connection, logger: logger)
    }

    /// This is the on-thread implementation for returning connections to the pool. Here we work out what to do with a newly-acquired
    /// connection.
    private func _returnConnection(_ connection: RedisConnection, logger: Logger) {
        self.loop.assertInEventLoop()

        guard connection.isConnected else {
            // This connection isn't active anymore. We'll dump it and potentially kick off a reconnection.
            self.refillConnections(logger: logger)
            return
        }

        switch self.state {
        case .active:
            // If anyone is waiting for a connection, let's give them this one. Otherwise, if there's room
            // in the pool, we'll put it there. Otherwise, we'll close it.
            if let waiter = self.connectionWaiters.popFirst() {
                self.leaseConnection(connection, to: waiter)
            } else if self.canAddConnectionToPool {
                self.availableConnections.append(connection)
            } else if let evictable = self.availableConnections.popFirst() {
                // We have at least one pooled connection. The returned is more recently active, so kick out the pooled
                // connection in favour of this one and close the recently evicted one.
                self.availableConnections.append(connection)
                _ = evictable.close()
            } else {
                // We don't need it, close it.
                _ = connection.close()
            }
        case .closed:
            // In general we shouldn't see leased connections return in .closed, as we should only be able to
            // transition to .closed when all the leases are back. We tolerate this in production builds by just closing the
            // connection, but in debug builds we assert to be sure.
            logger.warning("connection returned to closed pool", metadata: [
                RedisLogging.MetadataKeys.connectionID: "\(connection.id)"
            ])
            assertionFailure("Returned connection to closed pool")
            fallthrough
        case .closing:
            // We don't need this connection, close it.
            _ = connection.close()
            guard self.leasedConnectionCount == 0 else { return }
            self.state = .closed
        }
    }
}

extension ConnectionPool {
    fileprivate enum State {
        /// The connection pool is in active use.
        case active

        /// The user has requested the connection pool to close, but there are still active connections leased to users
        /// and in the pool.
        case closing

        /// The connection pool is closed: no connections are outstanding
        case closed
    }
}

extension ConnectionPool {
    /// A representation of a single waiter.
    struct Waiter {
        private var timeoutTask: Scheduled<Void>?

        private var result: EventLoopPromise<RedisConnection>

        var id: ObjectIdentifier {
            return ObjectIdentifier(self.result.futureResult)
        }

        var futureResult: EventLoopFuture<RedisConnection> {
            return self.result.futureResult
        }

        init(result: EventLoopPromise<RedisConnection>) {
            self.result = result
        }

        mutating func scheduleDeadline(loop: EventLoop, deadline: NIODeadline, _ onTimeout: @escaping () -> Void) {
            assert(self.timeoutTask == nil)
            self.timeoutTask = loop.scheduleTask(deadline: deadline, onTimeout)
        }

        func succeed(_ connection: RedisConnection) {
            self.timeoutTask?.cancel()
            self.result.succeed(connection)
        }

        func fail(_ error: Error) {
            self.timeoutTask?.cancel()
            self.result.fail(error)
        }
    }
}
