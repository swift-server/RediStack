//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2023 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import XCTest
@testable import RediStack

final class RedisClusterNodeDescriptionProtocolTests: XCTestCase {
    func testIsSame() {
        let node1 = MockNodeDescription(host: "redis1", ip: "127.0.0.1", useTLS: true)
        let node2 = MockNodeDescription(host: "redis2", ip: "127.0.0.2", useTLS: true)

        XCTAssertTrue(node1.isSame(node1))
        XCTAssertTrue(node2.isSame(node2))
        XCTAssertFalse(node2.isSame(node1))
    }

    func testNodeID() {
        let node1 = MockNodeDescription(host: "redis1", ip: "127.0.0.1", useTLS: true)
        let node2 = MockNodeDescription(host: "redis2", ip: "127.0.0.2", useTLS: true)

        XCTAssertEqual(node1.id, .init(endpoint: "redis1", port: 6379))
        XCTAssertEqual(node2.id, .init(endpoint: "redis2", port: 6379))
    }
}
