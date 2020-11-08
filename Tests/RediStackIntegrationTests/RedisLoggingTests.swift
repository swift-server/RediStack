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
        XCTAssertFalse(handler.messages.isEmpty)
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
                maximumConnectionCount: .maximumActiveConnections(1),
                connectionFactoryConfiguration: .init(connectionPassword: self.redisPassword)
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
}

final class TestLogHandler: LogHandler {
    var messages: [Logger.Message]
    var metadata: Logger.Metadata
    var logLevel: Logger.Level

    init() {
        self.messages = []
        self.metadata = [:]
        self.logLevel = .trace
    }

    func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, file: String, function: String, line: UInt) {
        self.messages.append(message)
    }

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { self.metadata[key] }
        set(newValue) { self.metadata[key] = newValue }
    }
}
