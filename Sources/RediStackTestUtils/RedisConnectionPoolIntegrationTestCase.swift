//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2020 Apple Inc. and the RediStack project authors
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
import RediStack
import XCTest

/// A helper `XCTestCase` subclass that does the standard work of creating a connection pool to use in test cases.
///
/// This is essentially the pooled version of `RedisIntegrationTestCase`
open class RedisConnectionPoolIntegrationTestCase: XCTestCase {
    /// An overridable value of the Redis instance's hostname to connect to for the test suite(s).
    ///
    /// The default value is `RedisConnection.defaultHostname`
    ///
    /// This is especially useful to override if you build on Linux & macOS where Redis might be installed locally vs. through Docker.
    open var redisHostname: String { RedisConnection.Configuration.defaultHostname }

    /// The port to connect over to Redis, defaulting to `RedisConnection.defaultPort`.
    open var redisPort: Int { RedisConnection.Configuration.defaultPort }

    /// The password to use to connect to Redis. Default is `nil` - no password authentication.
    open var redisPassword: String? { nil }

    public var pool: RedisConnectionPool!

    public let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 3)

    deinit {
        do {
            try self.eventLoopGroup.syncShutdownGracefully()
        } catch {
            print("Failed to gracefully shutdown ELG: \(error)")
        }
    }

    /// Creates a `RediStack.RedisConnectionPool` for the next test case, calling `fatalError` if it was not successful.
    ///
    /// See `XCTest.XCTestCase.setUp()`
    open override func setUp() {
        do {
            self.pool = try self.makeNewPool()
        } catch {
            fatalError("Failed to make a RedisConnectionPool: \(error)")
        }
    }

    /// Sends a "FLUSHALL" command to Redis to clear it of any data from the previous test, then closes the connection.
    ///
    /// If any steps fail, a `fatalError` is thrown.
    ///
    /// See `XCTest.XCTestCase.tearDown()`
    open override func tearDown() {
        do {
            _ = try self.pool.send(command: "FLUSHALL").wait()
        } catch let err as RedisConnectionPoolError where err == .poolClosed {
            // Ok, this is fine.
        } catch {
            fatalError("Failed to clean up the pool: \(error)")
        }

        self.pool.close()
        self.pool = nil
    }

    public func makeNewPool(
        connectionRetryTimeout: TimeAmount? = .seconds(5),
        minimumConnectionCount: Int = 0
    ) throws -> RedisConnectionPool {
        try self.makeNewPool(
            initialAddresses: nil,
            initialConnectionBackoffDelay: .milliseconds(100),
            connectionRetryTimeout: connectionRetryTimeout,
            minimumConnectionCount: minimumConnectionCount
        )
    }

    public func makeNewPool(
        initialAddresses: [SocketAddress]?,
        initialConnectionBackoffDelay: TimeAmount,
        connectionRetryTimeout: TimeAmount?,
        minimumConnectionCount: Int
    ) throws -> RedisConnectionPool {
        let addresses =
            try initialAddresses ?? [SocketAddress.makeAddressResolvingHost(self.redisHostname, port: self.redisPort)]
        let pool = RedisConnectionPool(
            configuration: RedisConnectionPool.Configuration(
                initialServerConnectionAddresses: addresses,
                maximumConnectionCount: .maximumActiveConnections(4),
                connectionFactoryConfiguration: .init(connectionPassword: self.redisPassword),
                minimumConnectionCount: minimumConnectionCount,
                initialConnectionBackoffDelay: initialConnectionBackoffDelay,
                connectionRetryTimeout: connectionRetryTimeout
            ),
            boundEventLoop: self.eventLoopGroup.next()
        )
        pool.activate()

        return pool
    }
}
