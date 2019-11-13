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

import RediStack
import RediStackTestUtils
import XCTest

final class PubSubCommandsTests: RediStackIntegrationTestCase {
    func test_singleChannel() throws {
        let futureExpectation = expectation(description: "Subscriber should receive a message")
        
        let subscriber = try self.makeNewConnection()
        defer { try? subscriber.close().wait() }
        
        let sentMessage = "Hello from Redis!"
        
        #warning("TODO")
//        _ = try? subscriber.subscribe(to: [#function]) { channel, message in
//            XCTAssertEqual(channel, #function)
//            XCTAssertEqual(message.string, sentMessage)
//            futureExpectation.fulfill()
//        }.wait()
        
        _ = try? self.connection.publish(sentMessage, toChannel: #function).wait()
        waitForExpectations(timeout: 1)
    }
}
