//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2023 Apple Inc. and the RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOCore
import XCTest

@testable import RediStack

final class RedisCommandEncoderTests: XCTestCase {

    var encoder: RedisCommandEncoder!

    override func setUp() {
        self.encoder = RedisCommandEncoder(buffer: ByteBuffer())
        super.setUp()
    }

    func testSimple() {
        self.encoder.encodeRESPArray("GET", "foo")
        var buffer = self.encoder.buffer

        var resp: RESPValue?
        XCTAssertNoThrow(resp = try RESPTranslator().parseBytes(from: &buffer))
        XCTAssertEqual(resp, .array([.bulkString(.init(string: "GET")), .bulkString(.init(string: "foo"))]))
    }

    func testStringAndByteBuffer() {
        let twelves = ByteBuffer(repeating: UInt8(ascii: "a"), count: 8)
        self.encoder.encodeRESPArray("SET", twelves)
        var buffer = self.encoder.buffer

        XCTAssert(buffer.readableBytesView.elementsEqual("*2\r\n$3\r\nSET\r\n$8\r\naaaaaaaa\r\n".utf8))

        var resp: RESPValue?
        XCTAssertNoThrow(resp = try RESPTranslator().parseBytes(from: &buffer))
        XCTAssertEqual(resp, .array([.bulkString(.init(string: "SET")), .bulkString(twelves)]))
    }

    func testSingleElement() {
        self.encoder.encodeRESPArray("FOO")
        var buffer = self.encoder.buffer

        XCTAssert(buffer.readableBytesView.elementsEqual("*1\r\n$3\r\nFOO\r\n".utf8))

        var resp: RESPValue?
        XCTAssertNoThrow(resp = try RESPTranslator().parseBytes(from: &buffer))
        XCTAssertEqual(resp, .array([.bulkString(.init(string: "FOO"))]))
    }

    func testSevenElements() {
        self.encoder.encodeRESPArray("SET", "key", "value", "NX", "GET", "EX", "60")
        var buffer = self.encoder.buffer

        var resp: RESPValue?
        XCTAssertNoThrow(resp = try RESPTranslator().parseBytes(from: &buffer))
        let expected = RESPValue.array([
            .bulkString(.init(string: "SET")),
            .bulkString(.init(string: "key")),
            .bulkString(.init(string: "value")),
            .bulkString(.init(string: "NX")),
            .bulkString(.init(string: "GET")),
            .bulkString(.init(string: "EX")),
            .bulkString(.init(string: "60")),
        ])
        XCTAssertEqual(resp, expected)
    }

}
