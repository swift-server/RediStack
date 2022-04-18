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

import NIO
import NIOEmbedded
@testable import RediStack
import RediStackTestUtils
import XCTest

final class RedisPubSubCommandsTests: RediStackIntegrationTestCase {
    func test_singleChannel() throws {
        let subscribeExpectation = self.expectation(description: "subscriber receives initial subscription message")
        let messageExpectation = self.expectation(description: "subscriber receives published message")
        let unsubscribeExpectation = self.expectation(description: "subscriber receives unsubscribe message")
        
        let subscriber = try self.makeNewConnection()
        defer { try? subscriber.close().wait() }

        let message = "Hello from Redis!"
        
        try subscriber.subscribe(
            to: #function,
            messageReceiver: {
                guard
                    $0 == #function,
                    $1.string == message
                else { return }
                messageExpectation.fulfill()
            },
            onSubscribe: {
                guard $0 == #function, $1 == 1 else { return }
                subscribeExpectation.fulfill()
            },
            onUnsubscribe: { details, eventSource in
                switch eventSource {
                case .clientError: return
                case .userInitiated:
                    guard
                        details.subscriptionKey == #function,
                        details.currentSubscriptionCount == 0
                    else { return }
                    unsubscribeExpectation.fulfill()
                }
            }
        ).wait()
        
        let subscribersCount = try self.connection.publish(message, to: #function).wait()
        XCTAssertEqual(subscribersCount, 1)
        
        try subscriber.unsubscribe(from: #function).wait()
        
        self.waitForExpectations(timeout: 1)
    }
    
    func test_multiChannel() throws {
        let channelMessageExpectation = self.expectation(description: "subscriber receives channel message")
        let patternMessageExpectation = self.expectation(description: "subscriber receives pattern message")
        
        let subscriber = try self.makeNewConnection()
        defer { try? subscriber.close().wait() }
        
        let channel = RedisChannelName(#function)
        let pattern = "\(channel.rawValue.dropLast(channel.rawValue.count / 2))*"

        try subscriber
            .subscribe(to: channel) { (_, _) in channelMessageExpectation.fulfill() }
            .wait()
        try subscriber
            .psubscribe(to: pattern) { (_, _) in patternMessageExpectation.fulfill() }
            .wait()
        
        let subscriberCount = try self.connection.publish("hello!", to: channel).wait()
        XCTAssertEqual(subscriberCount, 2)
        
        self.waitForExpectations(timeout: 1)
    }
    
    func test_unsubscribeWithoutSubscriptions() throws {
        XCTAssertNoThrow(try self.connection.unsubscribe(from: #function).wait())
    }
    
    func test_blockedCommandsThrowInPubSubMode() throws {
        try self.connection.subscribe(to: #function) { (_, _) in }.wait()
        defer { try? self.connection.unsubscribe(from: #function).wait() }
        
        XCTAssertThrowsError(try self.connection.send(.lpush("value", into: "List")).wait()) {
            XCTAssertTrue($0 is RedisError)
        }
    }
    
    func test_pingInPubSub() throws {
        try self.connection.subscribe(to: #function) { (_, _) in }.wait()
        defer { try? self.connection.unsubscribe(from: #function).wait() }
        
        let pong = try self.connection.ping().wait()
        XCTAssertEqual(pong, "PONG")
        
        let message = try self.connection.ping(with: "Hello").wait()
        XCTAssertEqual(message, "Hello")
    }
    
    func test_quitInPubSub() throws {
        try self.connection.subscribe(to: #function) { (_, _) in }.wait()
        defer { try? self.connection.unsubscribe(from: #function).wait() }
        
        let quit = RedisCommand<String>(keyword: "QUIT", arguments: [])
        let result = try self.connection.send(quit).wait()
        XCTAssertEqual(result, "OK")
    }
    
    func test_unsubscribeFromAllChannels() throws {
        let subscriber = try self.makeNewConnection()
        defer { try? subscriber.close().wait() }

        let channels = (1...5).map { RedisChannelName("\(#function)\($0)") }

        let expectation = self.expectation(description: "all channel subscriptions should be cancelled")
        expectation.expectedFulfillmentCount = channels.count

        try subscriber.subscribe(
            to: channels,
            messageReceiver: { _, _ in },
            onSubscribe: nil,
            onUnsubscribe: { _, _ in expectation.fulfill() }
        ).wait()
        
        XCTAssertTrue(subscriber.isSubscribed)
        try subscriber.unsubscribe().wait()
        XCTAssertFalse(subscriber.isSubscribed)
        
        self.waitForExpectations(timeout: 1)
    }

    func test_unsubscribeFromAllPatterns() throws {
        let subscriber = try self.makeNewConnection()
        defer { try? subscriber.close().wait() }
        
        let patterns = (1...3).map { ("*\(#function)\($0)") }
        
        let expectation = self.expectation(description: "all pattern subscriptions should be cancelled")
        expectation.expectedFulfillmentCount = patterns.count
        
        try subscriber.psubscribe(
            to: patterns,
            messageReceiver: { _, _ in },
            onSubscribe: nil,
            onUnsubscribe: { _, _ in expectation.fulfill() }
        ).wait()
        
        XCTAssertTrue(subscriber.isSubscribed)
        try subscriber.punsubscribe().wait()
        XCTAssertFalse(subscriber.isSubscribed)
        
        self.waitForExpectations(timeout: 1)
    }

    func test_unsubscribeFromAllMixed() throws {
        let subscriber = try self.makeNewConnection()
        defer { try? subscriber.close().wait() }

        let expectation = self.expectation(description: "both unsubscribes should be completed")
        expectation.expectedFulfillmentCount = 2

        XCTAssertFalse(subscriber.isSubscribed)

        try subscriber.subscribe(
            to: #function,
            messageReceiver: { _, _ in },
            onSubscribe: nil,
            onUnsubscribe: { _, _ in expectation.fulfill() }
        ).wait()
        XCTAssertTrue(subscriber.isSubscribed)
        
        try subscriber.psubscribe(
            to: "*\(#function)",
            messageReceiver: { _, _ in },
            onSubscribe: nil,
            onUnsubscribe: { _, _ in expectation.fulfill() }
        ).wait()
        XCTAssertTrue(subscriber.isSubscribed)

        try subscriber.unsubscribe().wait()
        XCTAssertTrue(subscriber.isSubscribed)
        
        try subscriber.punsubscribe().wait()
        XCTAssertFalse(subscriber.isSubscribed)

        self.waitForExpectations(timeout: 1)
    }

    func test_pubSubNumpat() throws {
        let queryConnection = try self.makeNewConnection()
        defer { try? queryConnection.close().wait() }

        let numPat = try queryConnection.send(.pubsubNumpat()).wait()
        XCTAssertGreaterThanOrEqual(numPat, 0)
    }

    func test_pubSubChannels() throws {
        let fn = #function
        let subscriber = try self.makeNewConnection()
        defer { try? subscriber.close().wait() }

        let channelNames = (1...10).map {
            RedisChannelName("\(fn)\($0)\($0 % 2 == 0 ? "_even" : "_odd")")
        }

        for channelName in channelNames {
            try subscriber.subscribe(
                to: channelName,
                messageReceiver: { _, _ in },
                onSubscribe: nil,
                onUnsubscribe: nil
            ).wait()
        }
        XCTAssertTrue(subscriber.isSubscribed)
        defer {
            // Unsubscribe (clean up)
            try? subscriber.unsubscribe(from: channelNames).wait()
            XCTAssertFalse(subscriber.isSubscribed)
        }

        // Make another connection to query on.
        let queryConnection = try self.makeNewConnection()
        defer { try? queryConnection.close().wait() }

        let oddChannels = try queryConnection.send(.pubsubChannels(matching: "\(fn)*_odd")).wait()
        XCTAssertEqual(oddChannels.count, channelNames.count / 2)

        let allChannels = try queryConnection.send(.pubsubChannels()).wait()
        XCTAssertGreaterThanOrEqual(allChannels.count, channelNames.count)
    }

    func test_pubSubNumsub() throws {
        let fn = #function
        let subscriber = try self.makeNewConnection()
        defer { try? subscriber.close().wait() }

        let channelNames = (1...5).map {
            RedisChannelName("\(fn)\($0)")
        }

        for channelName in channelNames {
            try subscriber.subscribe(
                to: channelName,
                messageReceiver: { _, _ in },
                onSubscribe: nil,
                onUnsubscribe: nil
            ).wait()
        }
        XCTAssertTrue(subscriber.isSubscribed)
        defer {
            // Unsubscribe (clean up)
            try? subscriber.unsubscribe(from: channelNames).wait()
            XCTAssertFalse(subscriber.isSubscribed)
        }

        // Make another connection to query on.
        let queryConnection = try self.makeNewConnection()
        defer { try? queryConnection.close().wait() }

        let notSubscribedChannel = RedisChannelName("\(fn)_notsubbed")
        let numSubs = try queryConnection.send(.pubsubNumsub(forChannels: [channelNames[0], notSubscribedChannel])).wait()
        XCTAssertEqual(numSubs.count, 2)

        XCTAssertGreaterThanOrEqual(numSubs[channelNames[0]] ?? 0, 1)
        XCTAssertEqual(numSubs[notSubscribedChannel], 0)
    }
}

final class RedisPubSubCommandsPoolTests: RediStackConnectionPoolIntegrationTestCase {
    func test_pool_singleChannel() throws {
        let subscribeExpectation = self.expectation(description: "subscriber receives initial subscription message")
        let messageExpectation = self.expectation(description: "subscriber receives published message")
        let unsubscribeExpectation = self.expectation(description: "subscriber receives unsubscribe message")
        
        let subscriber = try self.makeNewPool()
        defer { subscriber.close() }

        let message = "Hello from Redis!"
        
        try subscriber.subscribe(
            to: #function,
            messageReceiver: {
                guard
                    $0 == #function,
                    $1.string == message
                else { return }
                messageExpectation.fulfill()
            },
            onSubscribe: {
                guard $0 == #function, $1 == 1 else { return }
                subscribeExpectation.fulfill()
            },
            onUnsubscribe: { details, eventSource in
                switch eventSource {
                case .clientError: return
                case .userInitiated:
                    guard
                        details.subscriptionKey == #function,
                        details.currentSubscriptionCount == 0
                    else { return }
                    unsubscribeExpectation.fulfill()
                }
            }
        ).wait()
        XCTAssertEqual(subscriber.leasedConnectionCount, 1)
        
        let subscribersCount = try self.pool.publish(message, to: #function).wait()
        XCTAssertEqual(subscribersCount, 1)
        
        try subscriber.unsubscribe(from: #function).wait()
        XCTAssertEqual(subscriber.leasedConnectionCount, 0)
        
        self.waitForExpectations(timeout: 1)
    }

    func test_pool_multiChannel() throws {
        let channelMessageExpectation = self.expectation(description: "subscriber receives channel message")
        let patternMessageExpectation = self.expectation(description: "subscriber receives pattern message")
        
        let subscriber = try self.makeNewPool()
        defer { subscriber.close() }
        
        let channel = RedisChannelName(#function)
        let pattern = "\(channel.rawValue.dropLast(channel.rawValue.count / 2))*"

        try subscriber
            .subscribe(to: channel) { (_, _) in channelMessageExpectation.fulfill() }
            .wait()
        XCTAssertEqual(subscriber.leasedConnectionCount, 1)
        try subscriber
            .psubscribe(to: pattern) { (_, _) in patternMessageExpectation.fulfill() }
            .wait()
        XCTAssertEqual(subscriber.leasedConnectionCount, 1)
        
        let subscriberCount = try self.pool.publish("hello!", to: channel).wait()
        XCTAssertEqual(subscriberCount, 2)
        
        self.waitForExpectations(timeout: 1)
    }

    func test_unsubscribeWithoutSubscriptions() throws {
        XCTAssertEqual(self.pool.leasedConnectionCount, 0)
        XCTAssertNoThrow(try self.pool.unsubscribe(from: #function).wait())
        XCTAssertEqual(self.pool.leasedConnectionCount, 0)
    }
}

// MARK: - #103 tests

extension RedisPubSubCommandsTests {
    func test_pubsub_calls_unsubscribe_whenUnexpectedClose() throws {
        let channel = EmbeddedChannel()
        try channel
            .pipeline
            .addBaseRedisHandlers()
            .wait()

        let subscribeExpectation = self.expectation(description: "should see subscribe")
        let unsubscribeExpectation = self.expectation(description: "should see unsubscribe")

        let connection = RedisConnection(configuredRESPChannel: channel, defaultLogger: .init(label: ""))
        let subscribeFuture = connection
            .subscribe(
                to: [.init(#function)],
                messageReceiver: { _, _ in },
                onSubscribe: { _, _ in subscribeExpectation.fulfill() },
                onUnsubscribe: { _, eventSource in
                    switch eventSource {
                    case .userInitiated: return
                    case .clientError: unsubscribeExpectation.fulfill()
                    }
                }
            )

        // mimics a successful subscription response from the server
        let allocator = ByteBufferAllocator()
        var buffer = allocator.buffer(capacity: 300)
        buffer.writeRESPValue(.array([
            .init(bulk: "subscribe"),
            .init(bulk: "\(#function)"),
            .integer(1)
        ]))
        try channel.writeInbound(buffer)

        // lets the initial subscription work finish
        try subscribeFuture.wait()

        // 'unexpected' close, should trigger expectations
        try channel.close().wait()

        self.waitForExpectations(timeout: 0.5)
    }
}
