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
import struct Foundation.UUID
import NIO
import NIOConcurrencyHelpers
import Logging
import ServiceDiscovery

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

    /// The count of connections that are active and available for use.
    public var availableConnectionCount: Int { self.pool?.availableConnections.count ?? 0 }
    /// The number of connections that have been handed out and are in active use.
    public var leasedConnectionCount: Int { self.pool?.leasedConnectionCount ?? 0 }
    public var defaultLogger: Logger { self.configuration.poolDefaultLogger } // this is not defined in the RedisClient conformance extension below because of https://bugs.swift.org/browse/SR-14985

    private let loop: EventLoop
    // This needs to be var because we hand it a closure that references us strongly. This also
    // establishes a reference cycle which we need to break.
    // Aside from on init, all other operations on this var must occur on the event loop.
    private var pool: ConnectionPool?
    // This needs to be var because of some logger metadata tagging.
    // This should only be mutated on init, and safe to read anywhere else
    private var configuration: Configuration
    // This needs to be var because it is updatable and mutable.
    // As a result, aside from init, all use of this var must occur on the event loop.
    private var serverConnectionAddresses: ConnectionAddresses
    // This needs to be a var because its value changes as the pool enters/leaves pubsub mode to reuse the same connection.
    private var pubsubConnection: RedisConnection?
    // This array buffers any request for a connection that cannot be succeeded right away in the case where we have no target.
    // We never allow this to get larger than a specific bound, to resist DoS attacks. Past that bound we will fast-fail.
    private var requestsForConnections: [EventLoopPromise<RedisConnection>] = []
    // This is var because if we're using service discovery, we don't start doing that until activate is called.
    private var cancellationToken: CancellationToken? {
        willSet {
            guard let token = self.cancellationToken, !token.isCancelled, token !== newValue else {
                return
            }
            token.cancel()
        }
    }

    /// The maximum number of connection requests we'll buffer in `requestsForConnections` before we start fast-failing. These
    /// are buffered only when there are no available addresses to connect to, so in practice it's highly unlikely this will be
    /// hit, but either way, 100 concurrent connection requests ought to be plenty in this case.
    private static let maximumBufferedConnectionRequests = 100
    
    public init(configuration: Configuration, boundEventLoop: EventLoop) {
        var config = configuration

        self.loop = boundEventLoop
        self.serverConnectionAddresses = ConnectionAddresses(initialAddresses: config.initialConnectionAddresses)

        var taggedConnectionLogger = config.connectionConfiguration.defaultLogger
        taggedConnectionLogger[metadataKey: RedisLogging.MetadataKeys.connectionPoolID] = "\(self.id)"
        config.connectionConfiguration.defaultLogger = taggedConnectionLogger
        
        var taggedPoolLogger = config.poolDefaultLogger
        taggedPoolLogger[metadataKey: RedisLogging.MetadataKeys.connectionPoolID] = "\(self.id)"
        config.poolDefaultLogger = taggedPoolLogger
        
        self.configuration = config
        
        self.pool = ConnectionPool(
            minimumConnectionCount: self.configuration.connectionCountBehavior.minimumConnectionCount,
            maximumConnectionCount: self.configuration.connectionCountBehavior.maximumConnectionCount,
            maxConnectionCountBehavior: self.configuration.connectionCountBehavior.maxConnectionBehavior,
            connectionRetryStrategy: self.configuration.retryStrategy,
            loop: boundEventLoop,
            poolLogger: config.poolDefaultLogger,
            connectionFactory: self.connectionFactory(_:)
        )
    }
}

// MARK: Alternative initializers
extension RedisConnectionPool {
    /// Constructs a `RedisConnectionPool` that updates its addresses based on information from
    /// service discovery.
    ///
    /// This constructor behaves similarly to the regular constructor. However, it also activates the
    /// connection pool before returning it to the user. This is necessary because the act of subscribing
    /// to service discovery forms a reference cycle between the service discovery instance and the
    /// `RedisConnectionPool`. Pools constructed via this constructor _must_ always have `close` called
    /// on them.
    ///
    /// Pools created via this constructor will be auto-closed when the service discovery instance is completed for
    /// any reason, including on error. Users should still always call `close` in their own code during teardown.
    public static func activatedServiceDiscoveryPool<Discovery: ServiceDiscovery>(
        service: Discovery.Service,
        discovery: Discovery,
        configuration: Configuration,
        boundEventLoop: EventLoop,
        logger: Logger? = nil
    ) -> RedisConnectionPool where Discovery.Instance == SocketAddress {
        let pool = RedisConnectionPool(configuration: configuration, boundEventLoop: boundEventLoop)
        pool.beginSubscribingToServiceDiscovery(service: service, discovery: discovery, logger: logger)
        pool.activate(logger: logger)
        return pool
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

            self.pubsubConnection = nil

            // This breaks the cycle between us and the pool.
            self.pool = nil

            // Drop all pending connection attempts. No need to empty this manually, it'll get dropped regardless.
            for request in self.requestsForConnections {
                request.fail(RedisConnectionPoolError.poolClosed)
            }

            // This cancels service discovery.
            self.cancellationToken = nil
        }
    }

    /// Provides limited exclusive access to a connection to be used in a user-defined specialized closure of operations.
    /// - Warning: Attempting to create PubSub subscriptions with connections leased in the closure will result in a failed `NIO.EventLoopFuture`.
    ///
    /// `RedisConnectionPool` manages PubSub state and requires exclusive control over creating PubSub subscriptions.
    /// - Important: This connection **MUST NOT** be stored outside of the closure. It is only available exclusively within the closure.
    ///
    /// All operations should be done inside the closure as chained `NIO.EventLoopFuture` callbacks.
    ///
    /// For example:
    /// ```swift
    /// let countFuture = pool.leaseConnection {
    ///     let client = $0.logging(to: myLogger)
    ///     return client.authorize(with: userPassword)
    ///         .flatMap { connection.select(database: userDatabase) }
    ///         .flatMap { connection.increment(counterKey) }
    /// }
    /// ```
    /// - Warning: Some commands change the state of the connection that are not tracked client-side,
    /// and will not be automatically reset when the connection is returned to the pool.
    ///
    /// When the connection is reused from the pool, it will retain this state and may affect future commands executed with it.
    ///
    /// For example, if `select(database:)` is used, all future commands made with this connection will be against the selected database.
    ///
    /// To protect against future issues, make sure the final commands executed are to reset the connection to it's previous known state.
    /// - Parameters:
    ///     - eventLoop: An optional event loop to hop to for any further chaining on the returned event loop future.
    ///     - logger: An optional logger instance to use for logs generated from this operation.
    ///     - operation: A closure that receives exclusive access to the provided connection for the lifetime of the closure for specialized Redis command chains.
    /// - Returns: A `NIO.EventLoopFuture` that resolves the value of the `NIO.EventLoopFuture` in the provided closure operation.
    @inlinable
    public func leaseConnection<T>(
        eventLoop: EventLoop? = nil,
        logger: Logger? = nil,
        _ operation: @escaping (RedisConnection) -> EventLoopFuture<T>
    ) -> EventLoopFuture<T> {
        return self.forwardOperationToConnection(
            {
                (connection, returnConnection, logger) in
        
                return operation(connection)
                    .always { _ in returnConnection(connection, logger) }
            },
            preferredConnection: nil,
            eventLoop: eventLoop,
            taskLogger: logger
        )
    }

    /// Updates the list of valid connection addresses.
    /// - Warning: This will replace any previously set list of addresses.
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

            // Shiny, we can unbuffer any pending connections and pass them on as they now have somewhere to go.
            let unbufferedRequests = self.requestsForConnections
            self.requestsForConnections = []

            for request in unbufferedRequests {
                request.completeWith(self.connectionFactory(self.loop))
            }
        }
    }

    private func connectionFactory(_ targetLoop: EventLoop) -> EventLoopFuture<RedisConnection> {
        // Validate the loop invariants.
        self.loop.preconditionInEventLoop()
        targetLoop.preconditionInEventLoop()

        guard let nextTarget = self.serverConnectionAddresses.nextTarget() else {
            // No valid connection target, we'll keep track of the request and attempt to satisfy it later.
            // First, confirm we have space to keep track of this. If not, fast-fail.
            guard self.requestsForConnections.count < RedisConnectionPool.maximumBufferedConnectionRequests else {
                return targetLoop.makeFailedFuture(RedisConnectionPoolError.noAvailableConnectionTargets)
            }

            // Ok, we can buffer, let's do that.
            self.prepareLoggerForUse(nil).notice("waiting for target addresses")
            let promise = targetLoop.makePromise(of: RedisConnection.self)
            self.requestsForConnections.append(promise)
            return promise.futureResult
        }
        
        let connectionConfig: RedisConnection.Configuration
        do {
            connectionConfig = try .init(
                address: nextTarget,
                prototypeConfiguration: self.configuration.connectionConfiguration
            )
        } catch {
            // config validation failed, return the error
            return targetLoop.makeFailedFuture(error)
        }

        return RedisConnection
            .make(
                configuration: connectionConfig,
                boundEventLoop: targetLoop,
                configuredTCPClient: self.configuration.connectionConfiguration.tcpClient
            )
            .map { connection in
                // disallow subscriptions on all connections by default to enforce our management of PubSub state
                connection.allowSubscriptions = false
                return connection
            }
    }

    private func prepareLoggerForUse(_ logger: Logger?) -> Logger {
        guard var logger = logger else { return self.configuration.poolDefaultLogger }
        logger[metadataKey: RedisLogging.MetadataKeys.connectionPoolID] = "\(self.id)"
        return logger
    }

    /// A private helper function used for the service discovery constructor.
    private func beginSubscribingToServiceDiscovery<Discovery: ServiceDiscovery>(
        service: Discovery.Service,
        discovery: Discovery,
        logger: Logger?
    ) where Discovery.Instance == SocketAddress {
        self.loop.execute {
            let logger = self.prepareLoggerForUse(logger)

            self.cancellationToken = discovery.subscribe(
                to: service,
                onNext: { result in
                    // This closure may execute on any thread.
                    self.loop.execute {
                        switch result {
                        case .success(let targets):
                            self.updateConnectionAddresses(targets, logger: logger)
                        case .failure(let error):
                            logger.error("Service discovery error", metadata: [RedisLogging.MetadataKeys.error: "\(error)"])
                        }
                    }
                },
                onComplete: { (_: CompletionReason) in
                    // We don't really care about the reason, we just want to brick this client.
                    self.close(logger: logger)
                }
            )
        }
    }
}

// MARK: RedisClient
extension RedisConnectionPool: RedisClient {
    public var eventLoop: EventLoop { self.loop }

    public func logging(to logger: Logger) -> RedisClient {
        return CustomLoggerRedisClient(defaultLogger: logger, client: self)
    }
    
    public func send<CommandResult>(
        _ command: RedisCommand<CommandResult>,
        eventLoop: EventLoop? = nil,
        logger: Logger? = nil
    ) -> EventLoopFuture<CommandResult> {
        return self.forwardOperationToConnection(
            { (connection, returnConnection, logger) in

                connection.sendCommandsImmediately = true

                return connection
                    .send(command, eventLoop: eventLoop, logger: logger)
                    .always { _ in returnConnection(connection, logger) }
            },
            preferredConnection: nil,
            eventLoop: eventLoop,
            taskLogger: logger
        )
        .hop(to: eventLoop ?? self.eventLoop)
    }
    
    public func subscribe(
        to channels: [RedisChannelName],
        eventLoop: EventLoop? = nil,
        logger: Logger? = nil,
        messageReceiver receiver: @escaping RedisSubscriptionMessageReceiver,
        onSubscribe subscribeHandler: RedisSubscribeHandler?,
        onUnsubscribe unsubscribeHandler: RedisUnsubscribeHandler?
    ) -> EventLoopFuture<Void> {
        return self._subscribe(
            using: {
                $0.subscribe(
                    to: channels,
                    eventLoop: eventLoop,
                    logger: $2,
                    messageReceiver: receiver,
                    onSubscribe: subscribeHandler,
                    onUnsubscribe: $1
                )
            },
            onUnsubscribe: unsubscribeHandler,
            eventLoop: eventLoop,
            taskLogger: logger
        )
    }
    
    public func psubscribe(
        to patterns: [String],
        eventLoop: EventLoop? = nil,
        logger: Logger? = nil,
        messageReceiver receiver: @escaping RedisSubscriptionMessageReceiver,
        onSubscribe subscribeHandler: RedisSubscribeHandler?,
        onUnsubscribe unsubscribeHandler: RedisUnsubscribeHandler?
    ) -> EventLoopFuture<Void> {
        return self._subscribe(
            using: {
                $0.psubscribe(
                    to: patterns,
                    eventLoop: eventLoop,
                    logger: $2,
                    messageReceiver: receiver,
                    onSubscribe: subscribeHandler,
                    onUnsubscribe: $1
                )
            },
            onUnsubscribe: unsubscribeHandler,
            eventLoop: eventLoop,
            taskLogger: logger
        )
    }
    
    public func unsubscribe(
        from channels: [RedisChannelName],
        eventLoop: EventLoop? = nil,
        logger: Logger? = nil
    ) -> EventLoopFuture<Void> {
        return self._unsubscribe(
            using: { $0.unsubscribe(from: channels, eventLoop: eventLoop, logger: $1) },
            eventLoop: eventLoop,
            taskLogger: logger
        )
    }
    
    public func punsubscribe(
        from patterns: [String],
        eventLoop: EventLoop? = nil,
        logger: Logger? = nil
    ) -> EventLoopFuture<Void> {
        return self._unsubscribe(
            using: { $0.punsubscribe(from: patterns, eventLoop: eventLoop, logger: $1) },
            eventLoop: eventLoop,
            taskLogger: logger
        )
    }

    private func _subscribe(
        using operation: @escaping (RedisConnection, @escaping RedisUnsubscribeHandler, Logger) -> EventLoopFuture<Void>,
        onUnsubscribe unsubscribeHandler: RedisUnsubscribeHandler?,
        eventLoop: EventLoop?,
        taskLogger: Logger?
    ) -> EventLoopFuture<Void> {
        return self.forwardOperationToConnection(
            { (connection, returnConnection, logger) in

                if self.pubsubConnection == nil {
                    connection.allowSubscriptions = true // allow pubsub commands which are to come
                    self.pubsubConnection = connection
                }
                
                let onUnsubscribe: RedisUnsubscribeHandler = { subscriptionDetails, eventSource in
                    defer { unsubscribeHandler?(subscriptionDetails, eventSource) }
                    
                    guard
                        subscriptionDetails.currentSubscriptionCount == 0,
                        let connection = self.pubsubConnection
                    else { return }

                    connection.allowSubscriptions = false // reset PubSub permissions
                    returnConnection(connection, logger)
                    self.pubsubConnection = nil // break ref cycle
                }
                
                return operation(connection, onUnsubscribe, logger)
            },
            preferredConnection: self.pubsubConnection,
            eventLoop: eventLoop,
            taskLogger: taskLogger
        )
        .hop(to: eventLoop ?? self.loop)
    }

    private func _unsubscribe(
        using operation: @escaping (RedisConnection, Logger) -> EventLoopFuture<Void>,
        eventLoop: EventLoop?,
        taskLogger: Logger?
    ) -> EventLoopFuture<Void> {
        return self.forwardOperationToConnection(
            { (connection, returnConnection, logger) in
                return operation(connection, logger)
                    .always { _ in
                        // we aren't responsible for releasing the connection, subscribing is
                        // so we check if we have pubsub connection has been released, which indicates this might be
                        // a "no-op" unsub, so we need to return this connection
                        guard
                            self.pubsubConnection == nil,
                            self.leasedConnectionCount > 0
                        else { return }
                        returnConnection(connection, logger)
                    }
            },
            preferredConnection: self.pubsubConnection,
            eventLoop: eventLoop,
            taskLogger: taskLogger
        )
        .hop(to: eventLoop ?? self.loop)
    }

    /*
     pool.returnConnection is safe to call from any thread, as it does an event loop check before scheduling to run
     on the proper event loop for releasing the connection back into the pool

     as long as the operation just reads data from the pool or invokes the releaseConnection callback,
     then it is safe to invoke any of the commands on the provided connection with the user-provided event loop

     inside the operation closure, the closure has exclusive access to the connection to do what it needs
     */
    @usableFromInline
    internal func forwardOperationToConnection<T>(
        _ operation: @escaping (RedisConnection, @escaping (RedisConnection, Logger) -> Void, Logger) -> EventLoopFuture<T>,
        preferredConnection: RedisConnection?,
        eventLoop: EventLoop?,
        taskLogger: Logger?
    ) -> EventLoopFuture<T> {
        // Establish event loop context then jump to the in-loop version.
        guard self.loop.inEventLoop else {
            return self.loop.flatSubmit {
                return self.forwardOperationToConnection(
                    operation,
                    preferredConnection: preferredConnection,
                    eventLoop: eventLoop,
                    taskLogger: taskLogger
                )
            }
        }

        self.loop.preconditionInEventLoop()
        let finalEventLoop = eventLoop ?? self.loop

        guard let pool = self.pool else {
            return finalEventLoop.makeFailedFuture(RedisConnectionPoolError.poolClosed)
        }

        let logger = self.prepareLoggerForUse(taskLogger)
        
        guard let connection = preferredConnection else {
            return pool
                .leaseConnection(logger: logger)
                .flatMap { operation($0, pool.returnConnection(_:logger:), logger) }
        }

        return operation(connection, pool.returnConnection(_:logger:), logger)
    }
}

// MARK: Helper for creating connection configs

extension RedisConnection.Configuration {
    fileprivate init(address: SocketAddress, prototypeConfiguration: RedisConnectionPool.PoolConnectionConfiguration) throws {
        try self.init(
            address: address,
            password: prototypeConfiguration.password,
            initialDatabase: prototypeConfiguration.initialDatabase,
            defaultLogger: prototypeConfiguration.defaultLogger
        )
    }
}

// MARK: Helper for round-robin connection establishment
extension RedisConnectionPool {
    /// A helper structure for valid connection addresses. This structure implements round-robin connection establishment.
    private struct ConnectionAddresses {
        private var addresses: [SocketAddress]

        private var index: Array<SocketAddress>.Index
        
        internal init(initialAddresses: [SocketAddress]) {
            self.addresses = initialAddresses
            self.index = self.addresses.startIndex
        }
        
        internal mutating func nextTarget() -> SocketAddress? {
            // early exit on 0, makes life easier
            guard !self.addresses.isEmpty else {
                self.index = self.addresses.startIndex
                return nil
            }
            
            let nextTarget = self.addresses[self.index]
            
            // it's an invariant of this function that the index is always valid for subscripting the collection
            self.addresses.formIndex(after: &self.index)
            if self.index == self.addresses.endIndex {
                self.index = self.addresses.startIndex
            }
            
            return nextTarget
        }
        
        internal mutating func update(_ newAddresses: [SocketAddress]) {
            self.addresses = newAddresses
            self.index = self.addresses.startIndex
        }
    }
}
