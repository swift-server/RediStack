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

import NIO
@testable import RediStack
import XCTest

final class RedisMessageEncoderTests: XCTestCase {
    private var encoder: RedisMessageEncoder!
    private var allocator: ByteBufferAllocator!
    private var channel: EmbeddedChannel!

    override func setUp() {
        super.setUp()

        encoder = RedisMessageEncoder()
        allocator = ByteBufferAllocator()
        channel = EmbeddedChannel()
        _ = try? channel.pipeline.addHandler(MessageToByteHandler(encoder)).wait()
    }

    override func tearDown() {
        super.tearDown()

        _ = try? channel.finish()
    }

    func testSimpleStrings() throws {
        let simpleString1 = RESPValue.simpleString("Test1".byteBuffer)
        try runEncodePass(with: simpleString1) { XCTAssertEqual($0.readableBytes, 8) }
        XCTAssertNoThrow(try self.channel.writeOutbound(simpleString1))

        let simpleString2 = RESPValue.simpleString("®in§³¾".byteBuffer)
        try runEncodePass(with: simpleString2) { XCTAssertEqual($0.readableBytes, 13) }
        XCTAssertNoThrow(try self.channel.writeOutbound(simpleString2))
    }

    func testBulkStrings() throws {
        var buffer = allocator.buffer(capacity: 5)
        buffer.writeBytes([0x01, 0x02, 0x0a, 0x1b, 0xaa])
        let bs1 = RESPValue.bulkString(buffer)
        try runEncodePass(with: bs1) { XCTAssertEqual($0.readableBytes, 11) }
        XCTAssertNoThrow(try self.channel.writeOutbound(bs1))

        let bs2: RESPValue = .init(bulk: "®in§³¾")
        try runEncodePass(with: bs2) { XCTAssertEqual($0.readableBytes, 17) }
        XCTAssertNoThrow(try self.channel.writeOutbound(bs2))

        let bs3: RESPValue = .init(bulk: "")
        try runEncodePass(with: bs3) { XCTAssertEqual($0.readableBytes, 6) }
        XCTAssertNoThrow(try self.channel.writeOutbound(bs3))
    }

    func testIntegers() throws {
        let i1 = RESPValue.integer(Int.min)
        try runEncodePass(with: i1) { XCTAssertEqual($0.readableBytes, 23) }
        XCTAssertNoThrow(try self.channel.writeOutbound(i1))

        let i2 = RESPValue.integer(0)
        try runEncodePass(with: i2) { XCTAssertEqual($0.readableBytes, 4) }
        XCTAssertNoThrow(try self.channel.writeOutbound(i2))
    }

    func testArrays() throws {
        let a1 = RESPValue.array([])
        try runEncodePass(with: a1) { XCTAssertEqual($0.readableBytes, 4) }
        XCTAssertNoThrow(try self.channel.writeOutbound(a1))

        let a2: RESPValue = .array([.integer(3), .simpleString("foo".byteBuffer)])
        try runEncodePass(with: a2) { XCTAssertEqual($0.readableBytes, 14) }
        XCTAssertNoThrow(try self.channel.writeOutbound(a2))

        let bytes: [UInt8] = [ 0x0a, 0x1a, 0x1b, 0xff ]
        var buffer = allocator.buffer(capacity: bytes.count)
        buffer.writeBytes(bytes)
        let a3: RESPValue = .array([.array([
            .integer(3),
            .bulkString(buffer)
        ])])
        try runEncodePass(with: a3) { XCTAssertEqual($0.readableBytes, 22) }
        XCTAssertNoThrow(try self.channel.writeOutbound(a3))
    }

    func testError() throws {
        let error = RedisError(reason: "Manual error")
        let data = RESPValue.error(error)
        try runEncodePass(with: data) {
            XCTAssertEqual($0.readableBytes, "-\(error.message)\r\n".bytes.count)
        }
        XCTAssertNoThrow(try self.channel.writeOutbound(data))
    }

    func testNull() throws {
        let null = RESPValue.null
        try runEncodePass(with: null) { XCTAssertEqual($0.readableBytes, 5) }
        XCTAssertNoThrow(try self.channel.writeOutbound(null))
    }

    private func runEncodePass(with input: RESPValue, _ validation: (ByteBuffer) -> Void) throws {
        var buffer = allocator.buffer(capacity: 256)
        try encoder.encode(data: input, out: &buffer)
        validation(buffer)
    }
}

extension RedisMessageEncoderTests {
    static var allTests = [
        ("testSimpleStrings", testSimpleStrings),
        ("testBulkStrings", testBulkStrings),
        ("testIntegers", testIntegers),
        ("testArrays", testArrays),
        ("testError", testError),
        ("testNull", testNull),
    ]
}
