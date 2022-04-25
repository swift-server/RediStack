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
import ServiceDiscovery
import NIO
import RediStack
import RediStackTestUtils
import XCTest

final class RedisLoggingTests: RediStackIntegrationTestCase {
    func test_connectionUsesCustomLogger() throws {
        let handler = TestLogHandler()
        let logger = Logger(label: #function, factory: { _ in return handler })
        _ = try self.connection
            .logging(to: logger)
            .ping()
            .wait()
        XCTAssertFalse(handler.events.isEmpty)
    }

    func test_connectionLoggerOverride_usesProvidedLoggerInstead() throws {
        let defaultHandler = TestLogHandler()
        let defaultLogger = Logger(label: #function, factory: { _ in return defaultHandler })

        let expectedHandler = TestLogHandler()
        let expectedLogger = Logger(label: "something_else", factory: { _ in return expectedHandler })

        _ = try self.connection
            .logging(to: defaultLogger)
            .ping(logger: expectedLogger)
            .wait()

        XCTAssertTrue(defaultHandler.events.isEmpty)
        XCTAssertFalse(expectedHandler.events.isEmpty)
    }
    
    func test_connectionLoggerMetadata() throws {
        let handler = TestLogHandler()
        let logger = Logger(label: #function, factory: { _ in return handler })
        
        _ = try self.connection
            .logging(to: logger)
            .ping()
            .wait()
        XCTAssertEqual(
            handler.metadata[RedisLogging.MetadataKeys.connectionID],
            .string(self.connection.id.description)
        )
    }
    
    func test_poolLoggerMetadata() throws {
        let handler = TestLogHandler()
        let logger = Logger(label: #function, factory: { _ in return handler })
        
        let pool = RedisConnectionPool(
            configuration: .init(
                initialServerConnectionAddresses: [try .makeAddressResolvingHost(self.redisHostname, port: self.redisPort)],
                connectionCountBehavior: .strict(maximumConnectionCount: 1),
                connectionConfiguration: .init(password: self.redisPassword)
            ),
            boundEventLoop: self.connection.eventLoop
        )
        defer { pool.close() }
        pool.activate()
        
        _ = try pool
            .logging(to: logger)
            .ping()
            .wait()
        XCTAssertTrue(handler.metadata.keys.contains(RedisLogging.MetadataKeys.connectionID))
        XCTAssertEqual(
            handler.metadata[RedisLogging.MetadataKeys.connectionPoolID],
            .string(pool.id.uuidString)
        )
    }

    func test_serviceDiscoveryMetadata() throws {
        let handler = TestLogHandler()
        let logger = Logger(label: #function, factory: { _ in return handler })
        let hosts = InMemoryServiceDiscovery<String, SocketAddress>(configuration: .init())
        let config = RedisConnectionPool.Configuration(
            initialServerConnectionAddresses: [],
            connectionCountBehavior: .strict(maximumConnectionCount: 1),
            connectionConfiguration: .init(password: self.redisPassword)
        )
        let client = RedisConnectionPool.activatedServiceDiscoveryPool(
            service: "default.local",
            discovery: hosts,
            configuration: config,
            boundEventLoop: self.connection.eventLoop)
        defer {
            client.close()
        }

        let address = try SocketAddress.makeAddressResolvingHost(self.redisHostname, port: self.redisPort)
        hosts.register("default.local", instances: [address])

        _ = try client
            .logging(to: logger)
            .ping()
            .wait()
        XCTAssertTrue(handler.metadata.keys.contains(RedisLogging.MetadataKeys.connectionID))
        XCTAssertEqual(
            handler.metadata[RedisLogging.MetadataKeys.connectionPoolID],
            .string(client.id.uuidString)
        )
    }
}

final class TestLogHandler: LogHandler {
    var metadata: Logger.Metadata
    var logLevel: Logger.Level
    var events: [(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, file: String, function: String, line: UInt)]

    init() {
        self.metadata = [:]
        self.events = []
        self.logLevel = .trace
    }

    func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, file: String, function: String, line: UInt) {
        self.events.append((level, message, metadata, file, function, line))
    }

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { self.metadata[key] }
        set(newValue) { self.metadata[key] = newValue }
    }
}
