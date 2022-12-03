//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2019-2022 RediStack project authors
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

/// A helper `XCTestCase` subclass that does the standard work of creating a connection to use in test cases.
///
/// See `RedisConnection.make(configuration:boundEventLoop:)` to understand how connections are made.
open class RedisIntegrationTestCase: XCTestCase {
    /// An overridable value of the Redis instance's hostname to connect to for the test suite(s).
    ///
    /// The default value is `RedisConnection.defaultHostname`
    ///
    /// This is especially useful to override if you build on Linux & macOS where Redis might be installed locally vs. through Docker.
    open var redisHostname: String { RedisConnection.Configuration.defaultHostname }
    
    /// The port to connect over to Redis, defaulting to `RedisConnection.defaultPort`.
    open var redisPort: Int { RedisConnection.Configuration.defaultPort }
    
    /// The username to use to connect to Redis. Default is `nil` - use password authentication only.
    open var redisUsername: String? { return nil }

    /// The password to use to connect to Redis. Default is `nil` - no password authentication.
    open var redisPassword: String? { return nil }
    
    public var connection: RedisConnection!
    
    private let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)
    
    deinit {
        do {
            try self.eventLoopGroup.syncShutdownGracefully()
        } catch {
            print("Failed to gracefully shutdown ELG: \(error)")
        }
    }
    
    /// Creates a `RediStack.RedisConnection` for the next test case, calling `fatalError` if it was not successful.
    ///
    /// See `XCTest.XCTestCase.setUp()`
    open override func setUp() {
        do {
            connection = try self.makeNewConnection()
        } catch {
            fatalError("Failed to make a RedisConnection: \(error)")
        }
    }
    
    /// Sends a "FLUSHALL" command to Redis to clear it of any data from the previous test, then closes the connection.
    ///
    /// If any steps fail, a `fatalError` is thrown.
    ///
    /// See `XCTest.XCTestCase.tearDown()`
    open override func tearDown() {
        do {
            if self.connection.isConnected {
                _ = try self.connection.send(.flushall)
                    .flatMap { _ in self.connection.close() }
                    .wait()
            }
            
            self.connection = nil
        } catch {
            fatalError("Failed to properly cleanup connection: \(error)")
        }
    }
    
    /// Creates a new connection for use in tests.
    ///
    /// See `RedisConnection.make(configuration:boundEventLoop:)`
    /// - Returns: The new `RediStack.RedisConnection`.
    public func makeNewConnection() throws -> RedisConnection {
        return try RedisConnection.make(
            configuration: .init(
                host: self.redisHostname,
                port: self.redisPort,
                username: self.redisUsername,
                password: self.redisPassword
            ),
            boundEventLoop: eventLoopGroup.next()
        ).wait()
    }
}
