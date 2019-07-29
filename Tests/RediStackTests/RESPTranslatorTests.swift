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

import struct Foundation.Data
import NIO
@testable import RediStack
import XCTest

final class RESPTranslatorTests: XCTestCase {
    private let allocator = ByteBufferAllocator()
    private let parser = RESPTranslator()
}

// MARK: WRITING

extension RESPTranslatorTests {
    func testWriting_simpleStrings() {
        XCTAssertTrue(writingTestPass(input: .simpleString("Test1".byteBuffer), expected: "+Test1\r\n"))
        XCTAssertTrue(writingTestPass(input: .simpleString("®in§³¾".byteBuffer), expected: "+®in§³¾\r\n"))
    }
    
    func testWriting_bulkStrings() {
        let bytes: [UInt8] = [0x01, 0x02, 0x0a, 0x1b, 0xaa]
        var buffer = allocator.buffer(capacity: 5)
        buffer.writeBytes(bytes)
        XCTAssertTrue(writingTestPass(input: .bulkString(buffer), expected: "$5\r\n".bytes + bytes + "\r\n".bytes))
        XCTAssertTrue(writingTestPass(input: .init(bulk: "®in§³¾"), expected: "$10\r\n®in§³¾\r\n"))
        XCTAssertTrue(writingTestPass(input: .init(bulk: ""), expected: "$0\r\n\r\n"))
        XCTAssertTrue(writingTestPass(input: .init(bulk: Optional<Int>.none), expected: "$0\r\n\r\n"))
    }
    
    func testWriting_integers() {
        XCTAssertTrue(writingTestPass(input: .integer(Int.min), expected: ":\(Int.min)\r\n"))
        XCTAssertTrue(writingTestPass(input: .integer(0), expected: ":0\r\n"))
    }
    
    func testWriting_arrays() {
        XCTAssertTrue(writingTestPass(input: .array([]), expected: "*0\r\n"))
        XCTAssertTrue(writingTestPass(
            input: .array([ .integer(3), .simpleString("foo".byteBuffer) ]),
            expected: "*2\r\n:3\r\n+foo\r\n"
        ))
        let bytes: [UInt8] = [ 0x0a, 0x1a, 0x1b, 0xff ]
        var buffer = allocator.buffer(capacity: 4)
        buffer.writeBytes(bytes)
        XCTAssertTrue(writingTestPass(
            input: .array([ .array([ .integer(10), .bulkString(buffer) ]) ]),
            expected: "*1\r\n*2\r\n:10\r\n$4\r\n".bytes + bytes + "\r\n".bytes
        ))
    }
    
    func testWriting_errors() {
        let error = RedisError(reason: "Manual error")
        XCTAssertTrue(writingTestPass(input: .error(error), expected: "-\(error.message)\r\n"))
    }
    
    func testWriting_null() {
        XCTAssertTrue(writingTestPass(input: .null, expected: "$-1\r\n"))
    }
    
    func testWriting_foundationData() {
        let name = #function
        let data = Data(name.bytes).convertedToRESPValue()
        XCTAssertTrue(writingTestPass(input: data, expected: "$\(name.count)\r\n\(name)\r\n"))
    }
    
    private func writingTestPass(input: RESPValue, expected: [UInt8]) -> Bool {
        var buffer = allocator.buffer(capacity: expected.count)
        buffer.writeRESPValue(input)
        
        let result = buffer.getBytes(at: 0, length: buffer.readableBytes)
        
        return result == expected
    }
    
    private func writingTestPass(input: RESPValue, expected: String) -> Bool {
        var buffer = allocator.buffer(capacity: expected.count)
        buffer.writeRESPValue(input)
        
        let result = buffer.getString(at: 0, length: buffer.readableBytes)
        
        return result == expected
    }
}

// MARK: READING

fileprivate extension ByteBuffer {
    mutating func mimicTokenParse() {
        self.moveReaderIndex(forwardBy: 1)
    }
}

// MARK: Parse

extension RESPTranslatorTests {
    func testParsing_invalidToken() {
        var buffer = self.allocator.buffer(capacity: 128)
        buffer.writeString("!!!!")
        XCTAssertThrowsError(try self.parser.parseBytes(from: &buffer)) { error in
            XCTAssertEqual(error as? RESPTranslator.ParsingError, .invalidToken)
        }
    }
    
    func testParsing_invalidSymbols() {
        let testRESP = "&3\r\n"
        var buffer = allocator.buffer(capacity: testRESP.count)
        buffer.writeString(testRESP)
        
        XCTAssertThrowsError(try parser.parseBytes(from: &buffer))
        XCTAssertEqual(buffer.readerIndex, 0)
    }
    
    func testParsing_simpleString() throws {
        let value = try parseTest(inputRESP: "+OK\r\n")
        XCTAssertEqual(value?.string, "OK")
    }
    
    func testParsing_simpleString_chunked() throws {
        let values = try parseTest(withChunks: ["+OK\r", "\n+&t®in§³¾\r", "\n"])
        XCTAssertEqual(values.count, 2)
        XCTAssertEqual(values[0].string, "OK")
        XCTAssertEqual(values[1].string, "&t®in§³¾")
    }
    
    func testParsing_integer() throws {
        let value = try parseTest(inputRESP: ":300\r\n")
        XCTAssertEqual(value?.int, 300)
    }
    
    func testParsing_integer_chunked() throws {
        let values = try parseTest(withChunks: [":300\r", "\n:\(Int.min)\r", "\n:", "\(Int.max)", "\r", "\n"])
        XCTAssertEqual(values.count, 3)
        XCTAssertEqual(values[0].int, 300)
        XCTAssertEqual(values[1].int, Int.min)
        XCTAssertEqual(values[2].int, Int.max)
    }
    
    func testParsing_bulkStrings() throws {
        XCTAssertEqual(try parseTest(inputRESP: "$-1\r\n")?.isNull, true)
        XCTAssertEqual(try parseTest(inputRESP: "$0\r\n\r\n")?.string, "")
        XCTAssertEqual(try parseTest(inputRESP: "$1\r\n!\r\n")?.string, "!")
        XCTAssertEqual(
            try parseTest(input: "$1\r\n".bytes + [0xa3] + "\r\n".bytes)?.bytes,
            [0xa3]
        )
        XCTAssertEqual(
            try parseTest(input: "$1\r\n".bytes + [0xba] + "\r\n".bytes)?.bytes,
            [0xba]
        )
    }
    
    func testParsing_bulkStrings_chunked() throws {
        let t1 = try parseTest(withChunks: ["$3\r", "\naaa\r\n$", "4\r\nnio!\r\n"])
        XCTAssertEqual(t1.count, 2)
        XCTAssertTrue(t1[0].bytes?.count == 3)
        XCTAssertTrue(t1[1].bytes?.count == 4)

        let chunks: [[UInt8]] = [
            "$3\r".bytes,
            "\n".bytes + [0xAA, 0xA3, 0xFF] + "\r\n$".bytes,
            "4\r\n".bytes + [0xbb, 0x3a, 0xba, 0xFF] + "\r\n".bytes
        ]
        let t2 = try parseTest(withChunks: chunks)
        XCTAssertTrue(t2[0].bytes?.count == 3)
        XCTAssertTrue(t2[1].bytes?.count == 4)
    }
    
    func testParsing_arrays() throws {
        XCTAssertEqual(try parseTest(inputRESP: "*1\r\n+!\r\n")?.array?.count, 1)
        XCTAssertEqual(try parseTest(inputRESP: "*2\r\n*1\r\n:1\r\n:3\r\n")?.array?.count, 2)
        XCTAssertEqual(try parseTest(input: "*0\r\n".bytes)?.array?.count, 0)
        XCTAssertNil(try parseTest(input: "*-1\r\n".bytes)?.array)
    }
    
    func testParsing_arrays_chunked() throws {
        let t1 = try parseTest(withChunks: ["*2\r", "\n+a\r\n+c\r\n*", "0\r\n"])
        XCTAssertEqual(t1.count, 2)
        XCTAssertTrue(t1[0].array?.count == 2)
        XCTAssertEqual(t1[0].array?[0].string, "a")
        XCTAssertEqual(t1[0].array?[1].string, "c")
        XCTAssertTrue(t1[1].array?.count == 0)
        
        let t2 = try parseTest(withChunks: [
            "*-1\r".bytes,
            "\n".bytes,
            "*1\r".bytes,
            "\n+£\r\n".bytes
        ])
        XCTAssertEqual(t2.count, 2)
        XCTAssertTrue(t2[0].isNull)
        XCTAssertTrue(t2[1].array?.count == 1)
        XCTAssertEqual(t2[1].array?[0].string, "£")
    }
    
    func testParsing_error() throws {
        let expectedContent = "ERR unknown command 'foobar'"
        let testString = "-\(expectedContent)\r\n"
        
        var buffer = allocator.buffer(capacity: expectedContent.count)
        buffer.writeString(testString)
        
        guard let value = try parser.parseBytes(from: &buffer) else { return XCTFail("Failed to parse error") }
        
        XCTAssertEqual(value.error?.message.contains(expectedContent), true)
    }

    private func parseTest(inputRESP: String) throws -> RESPValue? {
        return try parseTest(input: inputRESP.bytes)
    }

    private func parseTest(input: [UInt8]) throws -> RESPValue? {
        var buffer = allocator.buffer(capacity: input.count)
        buffer.writeBytes(input)
        
        let result = try parser.parseBytes(from: &buffer)
        assert(buffer.readerIndex == buffer.writerIndex)
        
        return result
    }
    
    private func parseTest(withChunks messageChunks: [String]) throws -> [RESPValue] {
        return try parseTest(withChunks: messageChunks.map({ $0.bytes }))
    }
    
    private func parseTest(withChunks messageChunks: [[UInt8]]) throws -> [RESPValue] {
        var buffer = allocator.buffer(capacity: messageChunks.joined().count)
        
        var results = [RESPValue]()
        
        for chunk in messageChunks {
            buffer.writeBytes(chunk)
            
            guard let result = try parser.parseBytes(from: &buffer) else { continue }
            
            results.append(result)
        }
        
        assert(buffer.readerIndex == buffer.writerIndex)
        
        return results
    }
}

// MARK: Simple Strings

extension RESPTranslatorTests {
    func testParsing_simpleString_missingNewline() {
        XCTAssertNil(simpleStringParseTest("+OK"))
        XCTAssertNil(simpleStringParseTest("+OK\r"))
    }
    
    func testParsing_simpleString_withNoContent() {
        XCTAssertEqual(simpleStringParseTest("+\r\n"), "")
    }
    
    func testParsing_simpleString_withContent() {
        XCTAssertEqual(simpleStringParseTest("+ \r\n"), " ")
        XCTAssertEqual(simpleStringParseTest("+OK\r\n"), "OK")
        XCTAssertEqual(simpleStringParseTest("+OK\r\n+OTHER STRING\r\n"), "OK")
        XCTAssertEqual(simpleStringParseTest("+&t®in§³¾\r\n"), "&t®in§³¾")
    }
    
    func testParsing_simpleString_handlesRecursion() {
        let testString = "+OK\r\n+OTHER STRING\r\n"
    
        var buffer = allocator.buffer(capacity: testString.count)
        buffer.writeString(testString)
        
        buffer.mimicTokenParse()
        var first = parser.parseSimpleString(from: &buffer)!
        XCTAssertEqual(buffer.readerIndex, 5) // position of the 2nd '+'
        XCTAssertEqual(first.readBytes(length: first.readableBytes), "OK".bytes)
        
        buffer.mimicTokenParse()
        var second = parser.parseSimpleString(from: &buffer)!
        XCTAssertEqual(buffer.readerIndex, 20)
        XCTAssertEqual(second.readBytes(length: second.readableBytes), "OTHER STRING".bytes)
    }
    
    private func simpleStringParseTest(_ inputRESP: String) -> String? {
        var buffer = allocator.buffer(capacity: inputRESP.count)
        buffer.writeString(inputRESP)
        
        buffer.mimicTokenParse()
        
        guard let stringBuffer = parser.parseSimpleString(from: &buffer) else { return nil }
        
        return RESPValue.simpleString(stringBuffer).string
    }
}

// MARK: Integers

extension RESPTranslatorTests {
    func testParsing_integer_withAllBytes() {
        XCTAssertEqual(integerParseTest(":100\r\n"), 100)
        XCTAssertEqual(integerParseTest(":-100\r\n"), -100)
        XCTAssertEqual(integerParseTest(":\(Int.min)\r\n"), Int.min)
        XCTAssertEqual(integerParseTest(":\(Int.max)\r\n"), Int.max)
    }
    
    func testParsing_integer_missingBytes() {
        XCTAssertNil(integerParseTest(":\r"))
        XCTAssertNil(integerParseTest(":"))
        XCTAssertNil(integerParseTest(":\n"))
        XCTAssertNil(integerParseTest(":\r\n"))
    }
    
    func testParsing_integer_recursively() {
        let testString = ":1\r\n:300\r\n"
        
        var buffer = allocator.buffer(capacity: testString.count)
        buffer.writeString(testString)
        
        buffer.mimicTokenParse()
        let first = parser.parseInteger(from: &buffer)
        XCTAssertEqual(buffer.readerIndex, 4) // position of the 2nd ':'
        XCTAssertEqual(first, 1)
        
        buffer.mimicTokenParse()
        let second = parser.parseInteger(from: &buffer)
        XCTAssertEqual(buffer.readerIndex, 10)
        XCTAssertEqual(second, 300)
    }
    
    private func integerParseTest(_ inputRESP: String) -> Int? {
        var buffer = allocator.buffer(capacity: inputRESP.count)
        buffer.writeString(inputRESP)
        buffer.mimicTokenParse()
        return parser.parseInteger(from: &buffer)
    }
}

// MARK: Bulk Strings

extension RESPTranslatorTests {
    func testParsing_bulkString_sizeMismatch() {
        var buffer = self.allocator.buffer(capacity: 128)
        buffer.writeString("$2\r\ntoo long\r\n")
        buffer.mimicTokenParse()
        XCTAssertThrowsError(try self.parser.parseBulkString(from: &buffer)) { error in
            XCTAssertEqual(error as? RESPTranslator.ParsingError, .bulkStringSizeMismatch)
        }
    }
    
    func testParsing_bulkString_invalidNegativeSize() {
        var buffer = self.allocator.buffer(capacity: 128)
        buffer.writeString("$-4\r\nwhat\r\n")
        buffer.mimicTokenParse()
        XCTAssertThrowsError(try self.parser.parseBulkString(from: &buffer)) { error in
            XCTAssertEqual(error as? RESPTranslator.ParsingError, .invalidBulkStringSize)
        }
    }
    
    func testParsing_bulkString_SizeIsNaN() {
        var buffer = self.allocator.buffer(capacity: 128)
        buffer.writeString("$FOO\r\nwhat\r\n")
        buffer.mimicTokenParse()
        XCTAssertThrowsError(try self.parser.parseBulkString(from: &buffer)) { error in
            XCTAssertEqual(error as? RESPTranslator.ParsingError, .invalidBulkStringSize)
        }
    }
    
    func testParsing_bulkString_missingEndings() {
        for message in ["$6", "$6\r\n", "$6\r\nabcdef", "$0\r\n"] {
            XCTAssertNil(bulkStringParseTest(inputRESP: message))
        }
    }
    
    func testParsing_bulkString_withNoSize() {
        let result = bulkStringParseTest(inputRESP: "$0\r\n\r\n")
        XCTAssertEqual(result?.bytes?.count, 0)
    }
    
    func testParsing_bulkString_withContent() {
        let result = bulkStringParseTest(inputRESP: "$1\r\n:\r\n")?.bytes
        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(result?[0], .colon)
    }
    
    func testParsing_bulkString_null() {
        let result = bulkStringParseTest(inputRESP: "$-1\r\n")
        XCTAssertEqual(result?.isNull, true)
    }
    
    func testParsing_bulkString_rawBytes() {
        let bytes: [UInt8] = [0x00, 0x01, 0x02, 0x03, 0x0A, 0xFF]
        let allBytes = "$\(bytes.count)\r\n".bytes + bytes + "\r\n".bytes
        
        let result = bulkStringParseTest(input: allBytes)
        XCTAssertEqual(result?.bytes?.count, bytes.count)
    }
    
    func testParsing_bulkString_recursively() {
        let testString = "$0\r\n\r\n$5\r\nredis\r\n"
        
        var buffer = allocator.buffer(capacity: testString.count)
        buffer.writeString(testString)
        
        buffer.mimicTokenParse()
        let first = try? parser.parseBulkString(from: &buffer)
        XCTAssertEqual(buffer.readerIndex, 6) // position of the 2nd '$'
        
        buffer.mimicTokenParse()
        let second = try? parser.parseBulkString(from: &buffer)
        XCTAssertEqual(buffer.readerIndex, 17)
        
        XCTAssertEqual(first?.string, "")
        XCTAssertEqual(second?.string, "redis")
    }
    
    private func bulkStringParseTest(inputRESP: String) -> RESPValue? {
        return bulkStringParseTest(input: inputRESP.bytes)
    }
    
    private func bulkStringParseTest(input: [UInt8]) -> RESPValue? {
        var buffer = allocator.buffer(capacity: input.count)
        buffer.writeBytes(input)

        buffer.mimicTokenParse()
        
        guard let result = try? parser.parseBulkString(from: &buffer) else { return nil }
        return result
    }
}

// MARK: Arrays

extension RESPTranslatorTests {
    func testParsing_array_whenNull() throws {
        let result = try arrayParseTest(inputRESP: "*-1\r\n")
        XCTAssertEqual(result?.isNull, true)
    }
    
    func testParsing_array_whenEmpty() throws {
        let result = try arrayParseTest(inputRESP: "*0\r\n")
        XCTAssertEqual(result?.array?.count, 0)
    }
    
    func testParsing_array_withMixedTypes() throws {
        let result = try arrayParseTest(inputRESP: "*3\r\n:3\r\n+OK\r\n$1\r\na\r\n")?.array
        XCTAssertEqual(result?.count, 3)
        XCTAssertEqual(result?[0].int, 3)
        XCTAssertEqual(result?[1].string, "OK")
        XCTAssertEqual(result?[2].bytes?.count, 1)
    }
    
    func testParsing_array_withNullElements() throws {
        let result = try arrayParseTest(inputRESP: "*3\r\n:3\r\n$-1\r\n:30\r\n")?.array
        XCTAssertEqual(result?.count, 3)
        XCTAssertEqual(result?[0].int, 3)
        XCTAssertEqual(result?[1].isNull, true)
        XCTAssertEqual(result?[2].int, 30)
    }
    
    func testParsing_array_nested() throws {
        let result = try arrayParseTest(inputRESP: "*2\r\n:3\r\n*2\r\n:30\r\n:15\r\n")?.array
        XCTAssertEqual(result?.count, 2)
        XCTAssertEqual(result?[0].int, 3)
        let nested = result?[1].array
        XCTAssertEqual(nested?.count, 2)
        XCTAssertEqual(nested?[0].int, 30)
        XCTAssertEqual(nested?[1].int, 15)
    }
    
    func testParsing_array_recursively() throws {
        let testString = "*1\r\n:3\r\n*2\r\n+OK\r\n$3\r\nabc\r\n"
        
        var buffer = allocator.buffer(capacity: testString.count)
        buffer.writeString(testString)
        
        buffer.mimicTokenParse()
        let first = try parser.parseArray(from: &buffer)
        XCTAssertEqual(buffer.readerIndex, 8) // position of the 2nd '$'
        
        buffer.mimicTokenParse()
        let second = try parser.parseArray(from: &buffer)
        XCTAssertEqual(buffer.readerIndex, 26)
        
        guard
            let array1 = first?.array,
            let array2 = second?.array
        else { return XCTFail("Failed to parse both values") }
        
        XCTAssertEqual(array1.count, 1)
        XCTAssertEqual(array1[0].int, 3)
        XCTAssertEqual(array2.count, 2)
        XCTAssertEqual(array2[0].string, "OK")
        XCTAssertEqual(array2[1].string, "abc")
    }
    
    private func arrayParseTest(inputRESP: String) throws -> RESPValue? {
        return try arrayParseTest(input: inputRESP.bytes)
    }
    
    private func arrayParseTest(input: [UInt8]) throws -> RESPValue? {
        var buffer = allocator.buffer(capacity: input.count)
        buffer.writeBytes(input)
        buffer.mimicTokenParse()
        
        guard let result = try parser.parseArray(from: &buffer) else { return nil }
        return result
    }
}
