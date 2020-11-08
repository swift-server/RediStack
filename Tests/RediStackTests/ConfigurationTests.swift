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

import NIO
import RediStack
import XCTest

final class ConfigurationTests: XCTestCase {
    func test_connectionConfiguration_stringURLValidation() throws {
        XCTAssertNoThrow(try RedisConnection.Configuration(url: "redis://localhost:6379"))
        XCTAssertNoThrow(try RedisConnection.Configuration(url: "redis://localhost:6379/0"))
        XCTAssertNoThrow(try RedisConnection.Configuration(url: "redis://:password@localhost"))
        XCTAssertThrowsError(try RedisConnection.Configuration(url: "localhost:6379"))
        XCTAssertThrowsError(try RedisConnection.Configuration(url: "redis://:6379"))
        XCTAssertThrowsError(try RedisConnection.Configuration(url: "redis://localhost/-1"))
    }
    
    func test_connectionConfiguration_urlComponents() throws {
        let configuration = try RedisConnection.Configuration(url: "redis://:password@localhost:6666/1")
        XCTAssertEqual(configuration.hostname, "localhost")
        XCTAssertEqual(configuration.password, "password")
        XCTAssertEqual(configuration.port, 6666)
        XCTAssertEqual(configuration.initialDatabase, 1)
    }
    
    func test_connectionConfiguration_databaseIndex() throws {
        let address = try SocketAddress.makeAddressResolvingHost("localhost", port: RedisConnection.Configuration.defaultPort)
        XCTAssertThrowsError(try RedisConnection.Configuration(address: address, initialDatabase: -1)) {
            XCTAssertEqual($0 as? RedisConnection.Configuration.ValidationError, .outOfBoundsDatabaseID)
        }
    }
}
