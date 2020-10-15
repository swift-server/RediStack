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
