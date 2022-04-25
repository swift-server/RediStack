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

@testable import RediStack
@testable import RediStackTestUtils
import XCTest
import NIO

enum ConnectionPoolTestError: Error {
    case connectionFailedForSomeReason
}

final class ConnectionPoolTests: XCTestCase {
    var server: EmbeddedMockRedisServer!

    override func setUp() {
        self.server = .init()
    }

    override func tearDown() {
        XCTAssertNoThrow(try self.server.shutdown())
    }

    private func createAConnection() -> RedisConnection {
        let channel = self.server.createConnectedChannel()

        // Wrap it
        return RedisConnection(configuredRESPChannel: channel, defaultLogger: .redisBaseConnectionLogger)
    }

    func createPool(
        maximumConnectionCount: Int,
        minimumConnectionCount: Int,
        behavior: RedisConnectionPool.ConnectionCountBehavior.MaxConnectionBehavior
    ) -> ConnectionPool {
        return ConnectionPool(
            minimumConnectionCount: minimumConnectionCount,
            maximumConnectionCount: maximumConnectionCount,
            maxConnectionCountBehavior: behavior,
            connectionRetryStrategy: .exponentialBackoff(),
            loop: self.server.loop,
            poolLogger: .redisBaseConnectionPoolLogger,
            connectionFactory: { return $0.makeSucceededFuture(self.createAConnection()) }
        )
    }

    func createPool(
        maximumConnectionCount: Int,
        minimumConnectionCount: Int,
        behavior: RedisConnectionPool.ConnectionCountBehavior.MaxConnectionBehavior,
        connectionFactory: @escaping (EventLoop) -> EventLoopFuture<RedisConnection>
    ) -> ConnectionPool {
        return ConnectionPool(
            minimumConnectionCount: minimumConnectionCount,
            maximumConnectionCount: maximumConnectionCount,
            maxConnectionCountBehavior: behavior,
            connectionRetryStrategy: .exponentialBackoff(),
            loop: self.server.loop,
            poolLogger: .redisBaseConnectionPoolLogger,
            connectionFactory: connectionFactory
        )
    }

    func testPoolMaintainsMinimumConnections() throws {
        let pool = self.createPool(maximumConnectionCount: 8, minimumConnectionCount: 4, behavior: .elastic)
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 0)

        pool.activate()
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 4)

        let originalChannels = self.server.channels
        XCTAssertTrue(originalChannels.allMatch(self.server.channels))

        // Close some connections.
        for connection in self.server.channels.suffix(2) {
            connection.close(promise: nil)
        }

        // Run the loop. Two connections are dead and got replaced.
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 4)
        XCTAssertFalse(originalChannels.allMatch(self.server.channels))
        XCTAssertTrue(originalChannels.prefix(2).allMatch(self.server.channels.prefix(2)))
        XCTAssertTrue(originalChannels.suffix(2).noneMatch(self.server.channels.suffix(2)))

        // Close the pool.
        pool.close()
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 0)
    }

    func testConnectionPoolCanLeaseConnections() throws {
        let pool = self.createPool(maximumConnectionCount: 8, minimumConnectionCount: 4, behavior: .elastic)
        defer {
            pool.close()
        }

        pool.activate()
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 4)

        // Lease a connection and return it, in a loop. This should always be the last connection, because
        // we put it back before the next lease.
        var leased: [EmbeddedChannel] = []
        for _ in 0..<10 {
            pool.leaseConnection(deadline: .distantFuture).whenSuccess { connection in
                (connection.channel as? EmbeddedChannel).map { leased.append($0) }
                XCTAssertTrue((connection.channel as? EmbeddedChannel) === self.server.channels.last)
                pool.returnConnection(connection)
            }
            XCTAssertNoThrow(try self.server.runWhileActive())
            XCTAssertEqual(self.server.channels.count, 4)
        }

        XCTAssertEqual(leased.count, 10)
        XCTAssertTrue(leased.allSatisfy { $0 === self.server.channels.last })
    }

    func testNonLeakyParallelLease() throws {
        let pool = self.createPool(maximumConnectionCount: 8, minimumConnectionCount: 1, behavior: .strict)
        defer {
            pool.close()
        }

        pool.activate()
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 1)

        // Now we're going to try to take 8 leases. This should succeed without drama.
        var indicesAndChannels = ArraySlice<(Int, RedisConnection)>()
        for i in 0..<8 {
            pool.leaseConnection(deadline: .distantFuture).whenSuccess { connection in
                indicesAndChannels.append((i, connection))
            }
        }
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 8)
        XCTAssertTrue(self.server.channels.allMatch(ArraySlice(indicesAndChannels.compactMap { $0.1.channel as? EmbeddedChannel })))
        XCTAssertEqual(Array(0..<8), indicesAndChannels.map { $0.0 })

        // Now we're going to try to take out another 8 leases. The pool is not leaky, so these will queue.
        for i in 8..<16 {
            pool.leaseConnection(deadline: .distantFuture).whenSuccess { connection in
                indicesAndChannels.append((i, connection))
            }
        }
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 8)
        XCTAssertTrue(self.server.channels.allMatch(ArraySlice(indicesAndChannels.compactMap { $0.1.channel as? EmbeddedChannel })))
        XCTAssertEqual(Array(0..<8), indicesAndChannels.map { $0.0 })

        // Let's return 4 leases to the pool. These will be recycled in order.
        for element in indicesAndChannels.removeFirst(4) {
            pool.returnConnection(element.1)
        }
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 8)
        XCTAssertEqual(indicesAndChannels.count, 8)

        // The first 4 connections are now the last 4 returned.
        XCTAssertTrue(self.server.channels.prefix(4).allMatch(ArraySlice(indicesAndChannels.suffix(4).compactMap { $0.1.channel as? EmbeddedChannel })))
        XCTAssertTrue(self.server.channels.suffix(4).allMatch(ArraySlice(indicesAndChannels.prefix(4).compactMap { $0.1.channel as? EmbeddedChannel })))
        XCTAssertEqual(Array(4..<12), indicesAndChannels.map { $0.0 })

        // Let's do that again.
        for element in indicesAndChannels.removeFirst(4) {
            pool.returnConnection(element.1)
        }
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 8)
        XCTAssertEqual(indicesAndChannels.count, 8)

        // The channels are back to being in order again.
        XCTAssertTrue(self.server.channels.allMatch(ArraySlice(indicesAndChannels.compactMap { $0.1.channel as? EmbeddedChannel })))
        XCTAssertEqual(Array(8..<16), indicesAndChannels.map { $0.0 })
    }

    func testLeakyParallelLease() throws {
        let pool = self.createPool(maximumConnectionCount: 8, minimumConnectionCount: 1, behavior: .elastic)
        defer {
            pool.close()
        }

        pool.activate()
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 1)

        // Now we're going to try to take 8 leases. This should succeed without drama.
        var indicesAndChannels = ArraySlice<(Int, RedisConnection)>()
        for i in 0..<8 {
            pool.leaseConnection(deadline: .distantFuture).whenSuccess { connection in
                indicesAndChannels.append((i, connection))
            }
        }
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 8)
        XCTAssertTrue(self.server.channels.allMatch(ArraySlice(indicesAndChannels.compactMap { $0.1.channel as? EmbeddedChannel })))
        XCTAssertEqual(Array(0..<8), indicesAndChannels.map { $0.0 })

        // Now we're going to try to take out another 8 leases. The pool is leaky, so these will not queue: they all get connections.
        for i in 8..<16 {
            pool.leaseConnection(deadline: .distantFuture).whenSuccess { connection in
                indicesAndChannels.append((i, connection))
            }
        }
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 16)
        XCTAssertTrue(self.server.channels.allMatch(ArraySlice(indicesAndChannels.compactMap { $0.1.channel as? EmbeddedChannel })))
        XCTAssertEqual(Array(0..<16), indicesAndChannels.map { $0.0 })

        // Let's return all the leases to the pool. 8 of them, the last 8 to be returned, get closed.
        for element in indicesAndChannels {
            pool.returnConnection(element.1)
        }
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 8)
        XCTAssertTrue(self.server.channels.allSatisfy({ $0.isActive }))

        // Ask for another 16 connections. We'll create 8 more.
        for i in 16..<32 {
            pool.leaseConnection(deadline: .distantFuture).whenSuccess { connection in
                indicesAndChannels.append((i, connection))
            }
        }

        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 16)
    }

    func testReturningClosedConnectionsGetReopened() throws {
        let pool = self.createPool(maximumConnectionCount: 1, minimumConnectionCount: 1, behavior: .strict)
        defer {
            pool.close()
        }

        pool.activate()
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 1)

        // Lease this connection and close it, then return it. We're gonna queue up 2 leases.
        var leased = Array<RedisConnection>()
        for _ in 0..<2 {
            pool.leaseConnection(deadline: .distantFuture).whenSuccess { connection in
                leased.append(connection)
            }
        }
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(leased.count, 1)
        XCTAssertEqual(self.server.channels.count, 1)
        XCTAssertTrue(self.server.channels.allMatch(leased.compactMap { ($0.channel) as? EmbeddedChannel }[...]))

        // Ok, close the connection. It's dead now.
        _ = leased.first!.close()
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 0)

        // Now return it to the pool. The pool will notice it's out of connections and create a new one. It will then immediately lease that new connection
        // out to the new waiter.
        pool.returnConnection(leased.first!)
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 1)
        XCTAssertTrue(self.server.channels.allMatch(leased.dropFirst().compactMap { ($0.channel) as? EmbeddedChannel }[...]))
    }

    func testLeasingFromClosedPoolsFails() throws {
        let pool = self.createPool(maximumConnectionCount: 1, minimumConnectionCount: 1, behavior: .strict)
        pool.activate()
        pool.close()

        XCTAssertThrowsError(try pool.leaseConnection(deadline: .distantFuture).wait()) { error in
            XCTAssertEqual(error as? RedisConnectionPoolError, .poolClosed)
        }
    }

    func testNothingBadHappensWhenYouRepeatedlyCloseAPool() throws {
        let pool = self.createPool(maximumConnectionCount: 1, minimumConnectionCount: 1, behavior: .strict)
        pool.activate()

        // Just spam close
        for _ in 0..<10 {
            pool.close()
        }
    }

    func testPendingWaitersAreFailedOnPoolClose() throws {
        let pool = self.createPool(maximumConnectionCount: 1, minimumConnectionCount: 1, behavior: .strict)
        defer {
            pool.close()
        }

        pool.activate()
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 1)

        // We're going to lease the connection.
        var leased = Array<RedisConnection>()
        pool.leaseConnection(deadline: .distantFuture).whenSuccess { connection in
            leased.append(connection)
        }
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(leased.count, 1)

        // Now we're going to queue up 5 waiters.
        var errors: [RedisConnectionPoolError] = []
        for _ in 0..<5 {
            pool.leaseConnection(deadline: .distantFuture).whenFailure { error in
                if let error = error as? RedisConnectionPoolError {
                    errors.append(error)
                }
            }
        }
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(errors.count, 0)

        // Close the pool.
        pool.close()
        XCTAssertEqual(errors, Array(repeating: .poolClosed, count: 5))
    }

    func testConnectionsThatCompleteAfterCloseAreClosed() throws {
        var connectionPromise: EventLoopPromise<RedisConnection>? = nil
        let pool = self.createPool(maximumConnectionCount: 1, minimumConnectionCount: 1, behavior: .strict) { loop in
            XCTAssertTrue(loop === self.server.loop)
            connectionPromise = self.server.loop.makePromise()
            return connectionPromise!.futureResult
        }
        pool.activate()
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 0)
        XCTAssertNotNil(connectionPromise)

        // Ok, close the pool.
        pool.close()

        // Now complete the promise. The channel will be created and immediately closed, but
        // we won't notice the closure straight away.
        connectionPromise?.succeed(self.createAConnection())
        XCTAssertEqual(self.server.channels.count, 1)
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 0)
    }

    func testConnectionsCanFailAfterCloseWithoutIncident() throws {
        var connectionPromise: EventLoopPromise<RedisConnection>? = nil
        let pool = self.createPool(maximumConnectionCount: 1, minimumConnectionCount: 1, behavior: .strict) { loop in
            XCTAssertTrue(loop === self.server.loop)
            connectionPromise = self.server.loop.makePromise()
            return connectionPromise!.futureResult
        }
        pool.activate()
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 0)
        XCTAssertNotNil(connectionPromise)

        // Ok, close the pool.
        pool.close()

        // Now fail the promise. The channel will be created and immediately closed, but
        // we won't notice the closure straight away. Confirm no future connection attempts are made.
        let promise = connectionPromise
        connectionPromise = nil
        promise?.fail(ConnectionPoolTestError.connectionFailedForSomeReason)
        XCTAssertEqual(self.server.channels.count, 0)
        XCTAssertNil(connectionPromise)
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 0)
        XCTAssertNil(connectionPromise)
    }

    func testExponentialConnectionBackoff() throws {
        var connectionPromise: EventLoopPromise<RedisConnection>? = nil
        let pool = self.createPool(maximumConnectionCount: 1, minimumConnectionCount: 1, behavior: .strict) { loop in
            XCTAssertTrue(loop === self.server.loop)
            connectionPromise = self.server.loop.makePromise()
            return connectionPromise!.futureResult
        }
        pool.activate()
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 0)
        XCTAssertNotNil(connectionPromise)

        var delay = pool.connectionRetryStrategy.initialDelay
        let oneNanosecond = TimeAmount.nanoseconds(1)
        for _ in 0..<10 {
            let promise = connectionPromise
            connectionPromise = nil
            promise?.fail(ConnectionPoolTestError.connectionFailedForSomeReason)

            self.server.loop.advanceTime(by: delay - oneNanosecond)
            XCTAssertNil(connectionPromise)
            self.server.loop.advanceTime(by: oneNanosecond)
            XCTAssertNotNil(connectionPromise)

            delay = pool.connectionRetryStrategy.determineNewDelay(currentDelay: delay)
        }

        pool.close()
        connectionPromise?.fail(ConnectionPoolTestError.connectionFailedForSomeReason)
    }

    func testNonLeakyBucketWillKeepConnectingIfThereIsSpaceAndWaiters() throws {
        var connectionPromise: EventLoopPromise<RedisConnection>? = nil
        let pool = self.createPool(maximumConnectionCount: 1, minimumConnectionCount: 0, behavior: .strict) { loop in
            XCTAssertTrue(loop === self.server.loop)
            connectionPromise = self.server.loop.makePromise()
            return connectionPromise!.futureResult
        }
        pool.activate()
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 0)
        XCTAssertNil(connectionPromise)

        // Ok, apply a lease. It'll have to wait.
        let lease = pool.leaseConnection(deadline: .distantFuture)
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertNotNil(connectionPromise)

        var delay = pool.connectionRetryStrategy.initialDelay
        let oneNanosecond = TimeAmount.nanoseconds(1)
        for _ in 0..<10 {
            let promise = connectionPromise
            connectionPromise = nil
            promise?.fail(ConnectionPoolTestError.connectionFailedForSomeReason)

            self.server.loop.advanceTime(by: delay - oneNanosecond)
            XCTAssertNil(connectionPromise)
            self.server.loop.advanceTime(by: oneNanosecond)
            XCTAssertNotNil(connectionPromise)

            delay = pool.connectionRetryStrategy.determineNewDelay(currentDelay: delay)
        }

        pool.close()
        connectionPromise?.fail(ConnectionPoolTestError.connectionFailedForSomeReason)
        XCTAssertThrowsError(try lease.wait()) { error in
            XCTAssertEqual(error as? RedisConnectionPoolError, .poolClosed)
        }
    }

    func testLeakyBucketWillKeepConnectingIfThereAreWaitersEvenIfTheresNoSpace() throws {
        var connectionPromise: EventLoopPromise<RedisConnection>? = nil
        let pool = self.createPool(maximumConnectionCount: 1, minimumConnectionCount: 0, behavior: .elastic) { loop in
            XCTAssertTrue(loop === self.server.loop)
            connectionPromise = self.server.loop.makePromise()
            return connectionPromise!.futureResult
        }
        pool.activate()
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 0)
        XCTAssertNil(connectionPromise)

        // Ok, apply a lease and give it a connection.
        let lease = pool.leaseConnection(deadline: .distantFuture)
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertNotNil(connectionPromise)
        connectionPromise?.succeed(self.createAConnection())
        connectionPromise = nil
        let connection = try lease.wait()
        defer {
            connection.close()
            XCTAssertNoThrow(try self.server.runWhileActive())
        }

        // Now another lease. This one waits.
        let lease2 = pool.leaseConnection(deadline: .distantFuture)
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertNotNil(connectionPromise)

        var delay = pool.connectionRetryStrategy.initialDelay
        let oneNanosecond = TimeAmount.nanoseconds(1)
        for _ in 0..<10 {
            let promise = connectionPromise
            connectionPromise = nil
            promise?.fail(ConnectionPoolTestError.connectionFailedForSomeReason)

            self.server.loop.advanceTime(by: delay - oneNanosecond)
            XCTAssertNil(connectionPromise)
            self.server.loop.advanceTime(by: oneNanosecond)
            XCTAssertNotNil(connectionPromise)

            delay = pool.connectionRetryStrategy.determineNewDelay(currentDelay: delay)
        }

        pool.close()
        connectionPromise?.fail(ConnectionPoolTestError.connectionFailedForSomeReason)
        XCTAssertThrowsError(try lease2.wait()) { error in
            XCTAssertEqual(error as? RedisConnectionPoolError, .poolClosed)
        }
    }

    func testDeadlinesWork() throws {
        var promises: [EventLoopPromise<RedisConnection>] = []
        let pool = self.createPool(maximumConnectionCount: 8, minimumConnectionCount: 0, behavior: .elastic) { loop in
            let connectionPromise = self.server.loop.makePromise(of: RedisConnection.self)
            promises.append(connectionPromise)
            return connectionPromise.futureResult
        }
        defer {
            pool.close()
        }

        pool.activate()
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 0)
        XCTAssertEqual(promises.count, 0)

        // Lease a connection and return it, in a loop. This will not succeed immediately because we delay connection
        // establishment.
        var results = Array<Result<RedisConnection, RedisConnectionPoolError>?>(repeating: nil, count: 10)
        for i in 0..<10 {
            // Just to stress the code a bit we're going to retire these in backwards order.
            pool.leaseConnection(deadline: .uptimeNanoseconds(UInt64(10 - i))).whenComplete { result in
                results[i] = result.mapError { $0 as! RedisConnectionPoolError }
            }
            XCTAssertNoThrow(try self.server.runWhileActive())
            XCTAssertEqual(self.server.channels.count, 0)
            XCTAssertEqual(promises.count, i + 1)
            XCTAssertEqual(results.filter { $0 == nil }.count, 10)
        }

        // Ok, let's advance time. 5 waiters should explode. These will be the _last_ 5 waiters.
        XCTAssertNoThrow(self.server.loop.advanceTime(by: .nanoseconds(5)))
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 0)
        XCTAssertEqual(promises.count, 10)
        XCTAssertTrue(results.prefix(5).allSatisfy { $0.isNil })
        XCTAssertTrue(results.suffix(5).allSatisfy { $0.isError(.timedOutWaitingForConnection) })

        // The first 5 to explode would have been the last five we added. Succeed the first 5 connections. This will still complete the remaining 5 waiters.
        for promise in promises.prefix(5) {
            promise.succeed(self.createAConnection())
        }
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 5)
        XCTAssertEqual(promises.count, 10)
        XCTAssertTrue(results.prefix(5).compactMap { $0.channel }.allMatch(self.server.channels))
        XCTAssertTrue(results.suffix(5).allSatisfy { $0.isError(.timedOutWaitingForConnection) })

        // Now advance time. All of the waiters should have been cancelled, so nothing should happen here.
        XCTAssertNoThrow(self.server.loop.advanceTime(by: .nanoseconds(5)))
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 5)
        XCTAssertEqual(promises.count, 10)
        XCTAssertTrue(results.prefix(5).compactMap { $0.channel }.allMatch(self.server.channels))
        XCTAssertTrue(results.suffix(5).allSatisfy { $0.isError(.timedOutWaitingForConnection) })
    }

    func testPoolWillStoreConnectionIfWaiterGoesAway() throws {
        var connectionPromise: EventLoopPromise<RedisConnection>? = nil
        let pool = self.createPool(maximumConnectionCount: 1, minimumConnectionCount: 0, behavior: .elastic) { loop in
            XCTAssertTrue(loop === self.server.loop)
            connectionPromise = self.server.loop.makePromise()
            return connectionPromise!.futureResult
        }
        pool.activate()
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 0)
        XCTAssertNil(connectionPromise)

        // Ok, apply a lease and give it a deadline
        let lease = pool.leaseConnection(deadline: .uptimeNanoseconds(1))
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertNotNil(connectionPromise)

        // Time it out.
        XCTAssertNoThrow(self.server.loop.advanceTime(by: .nanoseconds(5)))
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertThrowsError(try lease.wait()) { error in
            XCTAssertEqual(error as? RedisConnectionPoolError, .timedOutWaitingForConnection)
        }

        // Now succeed the connection
        connectionPromise?.succeed(self.createAConnection())
        connectionPromise = nil

        // Now another lease. This one succeeds immediately using a connection from the pool.
        let lease2 = pool.leaseConnection(deadline: .distantFuture)
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertNil(connectionPromise)
        let connection = try lease2.wait()
        XCTAssertTrue(connection.channel as? EmbeddedChannel === self.server.channels.first)
        pool.returnConnection(connection)
    }

    func testPoolCorrectlyClosesItselfWhenLeasedConnectionsAreReturned() throws {
        let pool = self.createPool(maximumConnectionCount: 2, minimumConnectionCount: 1, behavior: .strict)
        defer {
            pool.close()
        }

        pool.activate()
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 1)

        // Lease a connection.
        let lease = pool.leaseConnection(deadline: .distantFuture)
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 1)
        let redisConn = try lease.wait()

        // Shut the pool down. This keeps the channel active, as it's leased.
        pool.close()
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 1)

        // Return the channel.
        pool.returnConnection(redisConn)
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 0)
    }

    func testLeasedConnectionsInExcessOfMaxReplacePooledOnes() throws {
        // This test validates that if a leaky pool has allowed extra connections, and all those connections are
        // returned back, the active connections are the ones that were returned to the pool last.
        let pool = self.createPool(maximumConnectionCount: 4, minimumConnectionCount: 0, behavior: .elastic)
        defer {
            pool.close()
        }

        pool.activate()
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 0)

        var connections: [RedisConnection] = []

        // We're going to lease 8 connections.
        for _ in 0..<8 {
            pool.leaseConnection(deadline: .distantFuture).whenSuccess { connection in
                connections.append(connection)
            }
        }

        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 8)
        XCTAssertEqual(connections.count, 8)
        XCTAssertTrue(connections.compactMap { $0.channel as? EmbeddedChannel }.allMatch(self.server.channels))

        // Now we're going to return all 8, in order.
        for connection in connections {
            pool.returnConnection(connection)
        }
        XCTAssertNoThrow(try self.server.runWhileActive())

        // We expect 4 connections still to be open, and for those to match the _last 4_ of the connections we were leased.
        XCTAssertEqual(self.server.channels.count, 4)
        XCTAssertTrue(connections.suffix(4).compactMap { $0.channel as? EmbeddedChannel }.allMatch(self.server.channels))
    }
}

extension ConnectionPoolTests {
    private func stopReconnectingIfThereAreNoWaiters(behavior: RedisConnectionPool.ConnectionCountBehavior.MaxConnectionBehavior) throws {
        var connectionPromise: EventLoopPromise<RedisConnection>? = nil
        let pool = self.createPool(maximumConnectionCount: 1, minimumConnectionCount: 0, behavior: behavior) { loop in
            XCTAssertTrue(loop === self.server.loop)
            connectionPromise = self.server.loop.makePromise()
            return connectionPromise!.futureResult
        }
        pool.activate()
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertEqual(self.server.channels.count, 0)
        XCTAssertNil(connectionPromise)

        // Ok, apply a lease and give it a deadline
        let lease = pool.leaseConnection(deadline: .uptimeNanoseconds(1))
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertNotNil(connectionPromise)

        // Fail the connection attempt. This will cause a reconnection in several hundred milliseconds: well after we
        // time out the wait.
        var promise = connectionPromise
        connectionPromise = nil
        promise?.fail(ConnectionPoolTestError.connectionFailedForSomeReason)

        // Time it out the waiter.
        XCTAssertNoThrow(self.server.loop.advanceTime(by: .nanoseconds(5)))
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertThrowsError(try lease.wait()) { error in
            XCTAssertEqual(error as? RedisConnectionPoolError, .timedOutWaitingForConnection)
        }
        XCTAssertNil(connectionPromise)

        // Now advance time the remaining amount.
        XCTAssertNoThrow(self.server.loop.advanceTime(by: pool.connectionRetryStrategy.initialDelay))
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertNotNil(connectionPromise)

        // Now fail the connection again.
        promise = connectionPromise
        connectionPromise = nil
        promise?.fail(ConnectionPoolTestError.connectionFailedForSomeReason)

        // Advance time again, by a lot. Hours. No further connection attempt occurs: we give up.
        XCTAssertNoThrow(self.server.loop.advanceTime(by: .hours(5)))
        XCTAssertNoThrow(try self.server.runWhileActive())
        XCTAssertNil(connectionPromise)
    }

    func testLeakyPoolStopsReconnecting() throws {
        try self.stopReconnectingIfThereAreNoWaiters(behavior: .elastic)
    }

    func testNonLeakyPoolStopsReconnectingIfThereAreNoWaiters() throws {
        // This is the same as the test above, but the pool isn't leaky.
        try self.stopReconnectingIfThereAreNoWaiters(behavior: .strict)
    }
}

// MARK: ConnectionPool context erasing overloads

extension ConnectionPool {
    func activate() { self.activate(logger: .redisBaseConnectionPoolLogger) }
    
    func leaseConnection(deadline: NIODeadline) -> EventLoopFuture<RedisConnection> {
        return self.leaseConnection(logger: .redisBaseConnectionPoolLogger, deadline: deadline)
    }
    
    func returnConnection(_ connection: RedisConnection) {
        self.returnConnection(connection, logger: .redisBaseConnectionPoolLogger)
    }
    
    func close(promise: EventLoopPromise<Void>? = nil) {
        self.close(promise: promise, logger: .redisBaseConnectionPoolLogger)
    }
}

// MARK: Test Helpers

extension Collection where Element == EmbeddedChannel {
    func allMatch<Other: Collection>(_ other: Other) -> Bool where Other.Element == EmbeddedChannel {
        if self.count != other.count {
            return false
        }

        return zip(self, other).allSatisfy { $0.0 === $0.1 }
    }

    func noneMatch<Other: Collection>(_ other: Other) -> Bool where Other.Element == EmbeddedChannel {
        if self.count != other.count {
            return false
        }

        return zip(self, other).allSatisfy { $0.0 !== $0.1 }
    }
}

extension RandomAccessCollection where SubSequence == Self {
    mutating func removeFirst(_ n: Int) -> SubSequence {
        let first = self.prefix(n)
        self = self.dropFirst(n)
        return first
    }
}


extension Optional where Wrapped == Result<RedisConnection, RedisConnectionPoolError> {
    var isNil: Bool {
        switch self {
        case .some: return false
        case .none: return true
        }
    }

    func isError(_ error: RedisConnectionPoolError) -> Bool {
        switch self {
        case .some(.failure(let actualError)):
            return error == actualError
        case .none, .some(.success):
            return false
        }
    }

    var channel: EmbeddedChannel? {
        switch self {
        case .some(.success(let conn)):
            return conn.channel as? EmbeddedChannel
        case .some(.failure), .none:
            return nil
        }
    }
}
