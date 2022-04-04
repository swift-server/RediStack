//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2021-2022 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Logging
import NIO
@testable import RediStack
import XCTest

final class RedisConnectionTests: XCTestCase {

}

// MARK: Unexpected Closures
extension RedisConnectionTests {
    func test_connectionUnexpectedlyCloses_invokesCallback() throws {
        let loop = EmbeddedEventLoop()

        let expectedClosureConnection = RedisConnection(
            configuredRESPChannel: EmbeddedChannel(loop: loop),
            defaultLogger: Logger(label: "")
        )
        let expectedClosureExpectation = self.expectation(description: "this should not be fulfilled")
        expectedClosureExpectation.isInverted = true

        expectedClosureConnection.onUnexpectedClosure = { expectedClosureExpectation.fulfill() }
        _ = expectedClosureConnection.close(logger: nil)

        let channel = EmbeddedChannel(loop: loop)
        let notExpectedClosureConnection = RedisConnection(
            configuredRESPChannel: channel,
            defaultLogger: Logger(label: "")
        )
        let notExpectedClosureExpectation = self.expectation(description: "this should be fulfilled")
        notExpectedClosureConnection.onUnexpectedClosure = { notExpectedClosureExpectation.fulfill() }

        _ = try channel.finish(acceptAlreadyClosed: true)

        self.waitForExpectations(timeout: 0.5)
    }
}
