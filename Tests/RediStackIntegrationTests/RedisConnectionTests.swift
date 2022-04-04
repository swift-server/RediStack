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

import NIO
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

// MARK: PubSub permissions

extension RedisConnectionTests {
    func test_subscriptionNotAllowedFails() throws {
        self.connection.allowSubscriptions = false
        let subscription = self.connection.subscribe(to: #function) { (_, _) in }

        XCTAssertThrowsError(try subscription.wait()) {
            guard let error = $0 as? RedisClientError else {
                XCTFail("unexpected error type: \(type(of: $0))")
                return
            }
            XCTAssertEqual(error, .pubsubNotAllowed)
        }
    }

    func test_subscriptionPermissionsChanged_endsSubscriptions() throws {
        let connection = try self.makeNewConnection()

        let subscriptionClosedExpectation = self.expectation(description: "subscription was closed")
        subscriptionClosedExpectation.expectedFulfillmentCount = 2

        _ = try connection.subscribe(
            to: #function,
            messageReceiver:  { _, _ in },
            onSubscribe: nil,
            onUnsubscribe: { _, _ in subscriptionClosedExpectation.fulfill() }
        ).wait()
        _ = try connection.psubscribe(
            to: #function,
            messageReceiver:  { _, _ in },
            onSubscribe: nil,
            onUnsubscribe: { _, _ in subscriptionClosedExpectation.fulfill() }
        ).wait()

        connection.allowSubscriptions = false

        self.waitForExpectations(timeout: 1)
    }
}

// MARK: EventLoop Hopping
extension RedisConnectionTests {
    func testCommandHopsEventLoop() throws {
        let eventLoop = MultiThreadedEventLoopGroup(numberOfThreads: 1).next()

        try self.connection.ping(eventLoop: eventLoop)
            .map { _ in eventLoop.assertInEventLoop() }
            .wait()

        try self.connection.ping()
            .map { _ in
                eventLoop.assertNotInEventLoop()
                self.connection.eventLoop.assertInEventLoop()
            }
            .wait()
    }

    func testSubscribeHopsEventLoop() throws {
        let eventLoop = MultiThreadedEventLoopGroup(numberOfThreads: 1).next()
        defer {
            try! self.connection
                .unsubscribe(from: #function, eventLoop: eventLoop)
                .map { _ in eventLoop.assertInEventLoop() }
                .wait()
        }

        try self.connection
            .subscribe(to: #function, eventLoop: eventLoop) { _, _ in }
            .map { _ in eventLoop.assertInEventLoop() }
            .wait()

        try self.connection
            .subscribe(to: #function) { _, _ in }
            .map { _ in
                eventLoop.assertNotInEventLoop()
                self.connection.eventLoop.assertInEventLoop()
            }
            .wait()
    }

    func testPSubscribeHopsEventLoop() throws {
        let eventLoop = MultiThreadedEventLoopGroup(numberOfThreads: 1).next()
        defer {
            try! self.connection
                .punsubscribe(from: #function, eventLoop: eventLoop)
                .map { _ in eventLoop.assertInEventLoop() }
                .wait()
        }

        try self.connection
            .psubscribe(to: #function, eventLoop: eventLoop) { _, _ in }
            .map { _ in eventLoop.assertInEventLoop() }
            .wait()

        try self.connection
            .psubscribe(to: #function) { _, _ in }
            .map { _ in
                eventLoop.assertNotInEventLoop()
                self.connection.eventLoop.assertInEventLoop()
            }
            .wait()
    }

    func testCloseHopsEventLoop() throws {
        let eventLoop = MultiThreadedEventLoopGroup(numberOfThreads: 1).next()

        try self.connection
            .close(eventLoop: eventLoop)
            .map { eventLoop.assertInEventLoop() }
            .wait()

        let other = try self.makeNewConnection()
        try other.close()
            .map {
                eventLoop.assertNotInEventLoop()
                other.eventLoop.assertInEventLoop()
            }
            .wait()
    }
}
