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
import RediStack
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
            onUnsubscribe: {
                guard $0 == #function, $1 == 0 else { return }
                unsubscribeExpectation.fulfill()
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
        
        XCTAssertThrowsError(try self.connection.lpush("value", into: "List").wait()) {
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
        
        let value = try self.connection.send(command: "QUIT").wait()
        XCTAssertEqual(value.string, "OK")
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

        let numPat = try queryConnection.patternSubscriberCount().wait()
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

        let oddChannels = try queryConnection.activeChannels(matching: "\(fn)*_odd").wait()
        XCTAssertEqual(oddChannels.count, channelNames.count / 2)

        let allChannels = try queryConnection.activeChannels().wait()
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
        let numSubs = try queryConnection.subscriberCount(forChannels: [channelNames[0], notSubscribedChannel]).wait()
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
            onUnsubscribe: {
                guard $0 == #function, $1 == 0 else { return }
                unsubscribeExpectation.fulfill()
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

// MARK: - #100 subscribe race condition

extension RedisPubSubCommandsTests {
    func test_pubsub_pipelineChanges_hasNoRaceCondition() throws {
        func runOperation(_ factory: (RedisChannelName) -> EventLoopFuture<Void>) -> EventLoopFuture<Void> {
            return .andAllSucceed(
                (0...100_000).reduce(into: []) {
                    result, index in

                    result.append(factory("\(#function)-\(index)"))
                },
                on: self.connection.eventLoop
            )
        }

        // subscribing (adding handler)
        try runOperation { self.connection.subscribe(to: $0) { _, _ in } }
            .wait()

        // unsubscribing (removing handler)
        try runOperation { self.connection.unsubscribe(from: $0) }
            .wait()

        try self.connection.close().wait()
    }
}
