//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2021-2023 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Logging
import NIOCore
import NIOEmbedded
@testable import RediStack
import XCTest

final class RedisConnectionTests: XCTestCase {

    var logger: Logger {
        Logger(label: "RedisConnectionTests")
    }

    func test_connectionUnexpectedlyCloses_invokesCallback() throws {
        let loop = EmbeddedEventLoop()

        let expectedClosureConnection = RedisConnection(
            configuredRESPChannel: EmbeddedChannel(loop: loop),
            backgroundLogger: self.logger
        )
        let expectedClosureExpectation = self.expectation(description: "this should not be fulfilled")
        expectedClosureExpectation.isInverted = true

        expectedClosureConnection.onUnexpectedClosure = { expectedClosureExpectation.fulfill() }
        _ = expectedClosureConnection.close(logger: nil)

        let channel = EmbeddedChannel(loop: loop)
        let notExpectedClosureConnection = RedisConnection(
            configuredRESPChannel: channel,
            backgroundLogger: Logger(label: "")
        )
        let notExpectedClosureExpectation = self.expectation(description: "this should be fulfilled")
        notExpectedClosureConnection.onUnexpectedClosure = { notExpectedClosureExpectation.fulfill() }

        _ = try channel.finish(acceptAlreadyClosed: true)

        self.waitForExpectations(timeout: 0.5)
    }

    func testAuthorizationWithUsername() {
        var maybeSocketAddress: SocketAddress?
        XCTAssertNoThrow(maybeSocketAddress = try SocketAddress.makeAddressResolvingHost("localhost", port: 0))
        guard let socketAddress = maybeSocketAddress else { return XCTFail("Expected a socketAddress") }
        var maybeConfiguration: RedisConnection.Configuration?
        XCTAssertNoThrow(maybeConfiguration = try .init(address: socketAddress, username: "username", password: "password"))
        guard let configuration = maybeConfiguration else { return XCTFail("Expected a configuration") }

        let channel = EmbeddedChannel(handlers: [RedisCommandHandler()])
        XCTAssertNoThrow(try channel.connect(to: socketAddress).wait())

        let connection = RedisConnection(configuredRESPChannel: channel, backgroundLogger: self.logger)
        let future = connection.start(configuration: configuration)

        var outgoing: RESPValue?
        XCTAssertNoThrow(outgoing = try channel.readOutbound(as: RESPValue.self))
        XCTAssertEqual(outgoing, .array([.bulkString("AUTH"), .bulkString("username"), .bulkString("password")]))
        XCTAssertNoThrow(try channel.writeInbound(RESPValue.simpleString("OK")))
        XCTAssertNoThrow(try future.wait())
    }

    func testAuthorizationWithoutUsername() {
        var maybeSocketAddress: SocketAddress?
        XCTAssertNoThrow(maybeSocketAddress = try SocketAddress.makeAddressResolvingHost("localhost", port: 0))
        guard let socketAddress = maybeSocketAddress else { return XCTFail("Expected a socketAddress") }
        var maybeConfiguration: RedisConnection.Configuration?
        XCTAssertNoThrow(maybeConfiguration = try .init(address: socketAddress, password: "password"))
        guard let configuration = maybeConfiguration else { return XCTFail("Expected a configuration") }

        let channel = EmbeddedChannel(handlers: [RedisCommandHandler()])
        XCTAssertNoThrow(try channel.connect(to: socketAddress).wait())

        let connection = RedisConnection(configuredRESPChannel: channel, backgroundLogger: self.logger)
        let future = connection.start(configuration: configuration)

        var outgoing: RESPValue?
        XCTAssertNoThrow(outgoing = try channel.readOutbound(as: RESPValue.self))
        XCTAssertEqual(outgoing, .array([.bulkString("AUTH"), .bulkString("password")]))
        XCTAssertNoThrow(try channel.writeInbound(RESPValue.simpleString("OK")))
        XCTAssertNoThrow(try future.wait())
    }
}

extension RESPValue {
    static func bulkString(_ string: String) -> Self {
        .bulkString(ByteBuffer(string: string))
    }

    static func simpleString(_ string: String) -> Self {
        .simpleString(ByteBuffer(string: string))
    }
}
