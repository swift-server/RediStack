//===----------------------------------------------------------------------===//
//
// This source file is part of the RedisNIO open source project
//
// Copyright (c) 2019 RedisNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RedisNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import RedisNIO
import RedisNIOTestUtils
import XCTest

final class RedisConnectionTests: RedisIntegrationTestCase {
    static let expectedLogsMessage = "The following log(s) in this test are expected."
    
    func test_unexpectedChannelClose() throws {
        print(RedisConnectionTests.expectedLogsMessage)
        
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
        print(RedisConnectionTests.expectedLogsMessage)
        
        self.connection.close()
        do {
            _ = try self.connection.ping().wait()
            XCTFail("ping() should throw when connection is closed.")
        } catch {
            XCTAssertTrue(error is RedisNIOError)
        }
    }
    
    static var allTests = [
        ("test_unexpectedChannelClose", test_unexpectedChannelClose),
        ("test_callingCloseMultipleTimes", test_callingCloseMultipleTimes),
        ("test_sendingCommandAfterClosing", test_sendingCommandAfterClosing),
    ]
}
