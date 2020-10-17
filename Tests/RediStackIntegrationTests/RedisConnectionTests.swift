//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2019-2020 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

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
