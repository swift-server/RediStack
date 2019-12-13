//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2019 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Logging
@testable import RediStack
import RediStackTestUtils
import XCTest

final class RedisConnectionTests: RediStackIntegrationTestCase {
    func test_unexpectedChannelClose() throws {
        XCTAssertTrue(self.connection.isConnected)
        try self.connection.channel.close().wait()
        XCTAssertFalse(self.connection.isConnected)
    }
    
    func test_callingCloseMultipleTimes() throws {
        let first = self.connection.close()
        let second = self.connection.close()
        XCTAssertNotEqual(first, self.connection.channel.closeFuture)
        XCTAssertEqual(second, self.connection.channel.closeFuture)
    }
    
    func test_sendingCommandAfterClosing() throws {
        self.connection.close()
        do {
            _ = try self.connection.ping().wait()
            XCTFail("ping() should throw when connection is closed.")
        } catch {
            XCTAssertTrue(error is RedisClientError)
        }
    }
}

// MARK: Logging

extension RedisConnectionTests {
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
            get { return self.metadata[key] }
            set(newValue) { self.metadata[key] = newValue }
        }
    }
    
    func test_customLogging() throws {
        let handler = TestLogHandler()
        let logger = Logger(label: "test", factory: { _ in return handler })
        _ = try self.connection.logging(to: logger).ping().wait()
        XCTAssert(!handler.messages.isEmpty)
    }
  
    func test_loggingMetadata() throws {
        let handler = TestLogHandler()
        let logger = Logger(label: #function, factory: { _ in return handler })
        self.connection.setLogging(to: logger)
        let metadataKey = String(describing: RedisConnection.self)
        XCTAssertTrue(handler.metadata.keys.contains(metadataKey))
        XCTAssertEqual(
            handler.metadata[metadataKey],
            .string(self.connection.id.description)
        )
    }
}
