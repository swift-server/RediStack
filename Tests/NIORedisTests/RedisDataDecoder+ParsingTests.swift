import Foundation
import NIO
@testable import NIORedis
import XCTest

final class RedisDataDecoderParsingTests: XCTestCase {
    private let allocator = ByteBufferAllocator()

    func testParsing_with_simpleString() throws {
        try parseTest_singleValue(input: "+OK\r\n")
    }

    func testParsing_with_simpleString_recursively() throws {
        try parseTest_recursive(withChunks: ["+OK\r", "\n+OTHER STRING\r", "\n+&t®in§³¾\r", "\n"])
    }

    func testParsing_with_integer() throws {
        try parseTest_singleValue(input: ":300\r\n")
    }

    func testParsing_with_integer_recursively() throws {
        try parseTest_recursive(withChunks: [":300\r", "\n:-10135135\r", "\n:1\r", "\n"])
    }

    func testParsing_with_bulkString() throws {
        try parseTest_singleValue(input: "$-1\r\n")
        try parseTest_singleValue(input: "$0\r\n\r\n")
        try parseTest_singleValue(input: "$1\r\n!\r\n")
        try parseTest_singleValue(input: "$1\r\n".convertedToData() + Data(bytes: [0xff] + "\r\n".convertedToData()))

        let data = "$1\r\n".convertedToData() + Data(bytes: [0xba]) + "\r\n".convertedToData()
        try parseTest_singleValue(input: data)
    }

    func testParsing_with_bulkString_recursively() throws {
        try parseTest_recursive(withChunks: ["$3\r", "\naaa\r\n$", "4\r\nnio!\r\n"])
        try parseTest_recursive(withChunks: [
            "$3\r".convertedToData(),
            "\n".convertedToData() + Data(bytes: [0xAA, 0xA3, 0xFF]) + "\r\n$".convertedToData(),
            "4\r\n".convertedToData() + Data(bytes: [0xbb, 0x3a, 0xba, 0xFF]) + "\r\n".convertedToData()
        ])
    }

    func testParsing_with_arrays() throws {
        try parseTest_singleValue(input: "*1\r\n+!\r\n")
        try parseTest_singleValue(input: "*2\r\n*1\r\n:1\r\n:3\r\n")
        try parseTest_singleValue(input: "*0\r\n".convertedToData())
        try parseTest_singleValue(input: "*-1\r\n".convertedToData())
    }

    func testParsing_with_arrays_recursively() throws {
        try parseTest_recursive(withChunks: ["*2\r", "\n+a\r\n+a\r\n*", "0\r\n"])
        try parseTest_recursive(withChunks: ["*-1\r".convertedToData(), "\n".convertedToData()])
    }

    /// See parse_Test_singleValue(input:) String
    private func parseTest_singleValue(input: String) throws {
        try parseTest_singleValue(input: input.convertedToData())
    }

    /// Takes a collection of bytes representing a complete message
    private func parseTest_singleValue(input: Data) throws {
        let decoder = RedisDataDecoder()
        var buffer = allocator.buffer(capacity: input.count + 1)
        buffer.write(bytes: input)

        var position = 0

        XCTAssertEqual(try decoder._parse(at: &position, from: buffer), .parsed)
    }

    /// See parseTest_recursive(withCunks:) [Data]
    private func parseTest_recursive(withChunks messageChunks: [String]) throws {
        try parseTest_recursive(withChunks: messageChunks.map({ $0.convertedToData() }))
    }

    /// Takes a collection of byte streams to write to a buffer and assert decoding states in between
    /// buffer writes.
    /// The expected pattern of messages should be [incomplete, remaining, incomplete, remaining]
    private func parseTest_recursive(withChunks messageChunks: [Data]) throws {
        let decoder = RedisDataDecoder()
        var buffer = allocator.buffer(capacity: messageChunks.joined().count)
        buffer.write(bytes: messageChunks[0])

        var position = 0

        XCTAssertEqual(try decoder._parse(at: &position, from: buffer), .notYetParsed)

        for index in 1..<messageChunks.count {
            position = 0

            buffer.write(bytes: messageChunks[index])

            XCTAssertEqual(try decoder._parse(at: &position, from: buffer), .parsed)

            _ = buffer.readBytes(length: position)

            XCTAssertEqual(try decoder._parse(at: &position, from: buffer), .notYetParsed)
        }
    }
}

// MARK: Simple String Parsing

extension RedisDataDecoderParsingTests {
    func testParsing_simpleString_missingEndings_returnsNil() throws {
        XCTAssertNil(try parseTestSimpleString("+OK"))
        XCTAssertNil(try parseTestSimpleString("+OK\r"))
        XCTAssertNil(try parseTestSimpleString("+OK\n"))
    }

    func testParsing_simpleString_withNoContent_returnsEmpty() throws {
        XCTAssertEqual(try parseTestSimpleString("+ \r\n"), " ")
        XCTAssertEqual(try parseTestSimpleString("+\r\n"), "")
    }

    func testParsing_simpleString_withContent_returnsExpectedContent() throws {
        XCTAssertEqual(try parseTestSimpleString("+OK\r\n"), "OK")
        XCTAssertEqual(try parseTestSimpleString("+OK\r\n+OTHER STRING\r\n"), "OK")
        XCTAssertEqual(try parseTestSimpleString("+&t®in§³¾\r\n"), "&t®in§³¾")
    }

    func testParsing_simpleString_handlesRecursion() throws {
        let decoder = RedisDataDecoder()
        let testString = "+OK\r\n+OTHER STRING\r\n"
        var buffer = allocator.buffer(capacity: testString.count)
        buffer.write(string: testString)

        var position = 1 // "trim" token

        _ = try decoder._parseSimpleString(at: &position, from: buffer)

        XCTAssertEqual(position, 5) // position of the 2nd '+'

        position += 1 // "trim" token

        XCTAssertEqual(try decoder._parseSimpleString(at: &position, from: buffer), "OTHER STRING")
        XCTAssertEqual(position, buffer.writerIndex)
    }

    private func parseTestSimpleString(_ input: String) throws -> String? {
        var buffer = allocator.buffer(capacity: input.count)
        buffer.write(string: input)

        var position = 1 // "trim" token
        return try RedisDataDecoder()._parseSimpleString(at: &position, from: buffer)
    }
}

// MARK: Integer Parsing

extension RedisDataDecoderParsingTests {
    func testParsing_integer_missingEndings_returnsNil() throws {
        XCTAssertNil(try parseTestInteger("+OK"))
        XCTAssertNil(try parseTestInteger(":\r"))
        XCTAssertNil(try parseTestInteger(":\n"))
        XCTAssertNil(try parseTestInteger(": \r\n"))
        XCTAssertNil(try parseTestInteger(":\r\n"))
    }

    func testParsing_integer_withContent_returnsExpectedContent() throws {
        XCTAssertEqual(try parseTestInteger(":100\r\n"), 100)
        XCTAssertEqual(try parseTestInteger(":-100\r\n"), -100)
        XCTAssertEqual(try parseTestInteger(":-9223372036854775807\r\n+OTHER STRING\r\n"), -9223372036854775807)
        XCTAssertEqual(try parseTestInteger(":9223372036854775807\r\n"), 9223372036854775807)
    }

    func testParsing_integer_handlesRecursion() throws {
        let decoder = RedisDataDecoder()
        let testString = ":1\r\n:300\r\n"
        var buffer = allocator.buffer(capacity: testString.count)
        buffer.write(string: testString)

        var position = 1 // "trim" symbol

        _ = try decoder._parseInteger(at: &position, from: buffer)

        XCTAssertEqual(position, 4) // position of the next ':'

        position += 1 // "trim" token

        XCTAssertEqual(try decoder._parseInteger(at: &position, from: buffer), 300)
        XCTAssertEqual(position, buffer.writerIndex)
    }

    private func parseTestInteger(_ input: String) throws -> Int? {
        var buffer = allocator.buffer(capacity: input.count)
        buffer.write(string: input)

        var position = 1 // "trim" token
        return try RedisDataDecoder()._parseInteger(at: &position, from: buffer)
    }
}

// MARK: BulkString Parsing

extension RedisDataDecoderParsingTests {
    func testParsing_bulkString_handlesMissingEndings() throws {
        XCTAssertEqual(try parseTestBulkString("$6"), .notYetParsed)
        XCTAssertEqual(try parseTestBulkString("$6\r\n"), .notYetParsed)
        XCTAssertEqual(try parseTestBulkString("$6\r\nabcdef"), .notYetParsed)
    }

    func testParsing_bulkString_withNoSize_returnsEmpty() throws {
        XCTAssertEqual(try parseTestBulkString("$0\r\n"), .parsed)
    }

    func testParsing_bulkString_withSize_returnsContent() throws {
        XCTAssertEqual(try parseTestBulkString("$1\r\n1\r\n"), .parsed)
    }

    func testParsing_bulkString_withNull_returnsNil() throws {
        XCTAssertEqual(try parseTestBulkString("$-1\r\n"), .parsed)
    }

    func testParsing_bulkString_handlesRawBytes() throws {
        let bytes: [UInt8] = [0x00, 0x01, 0x02, 0x03, 0x0A, 0xFF]
        let data = "$\(bytes.count)\r\n".convertedToData() + Data(bytes: bytes) + "\r\n".convertedToData()
        XCTAssertEqual(try parseTestBulkString(data), .parsed)
    }

    func testParsing_bulkString_handlesLargeSizes() throws {
        let bytes = [UInt8].init(repeating: .dollar, count: 1_000_000)
        let data = "$\(bytes.count)\r\n".convertedToData() + Data(bytes: bytes) + "\r\n".convertedToData()
        XCTAssertEqual(try parseTestBulkString(data), .parsed)
    }

    private func parseTestBulkString(_ input: String) throws -> RedisDataDecoder._RedisDataDecodingState {
        return try parseTestBulkString(input.convertedToData())
    }

    private func parseTestBulkString(_ input: Data) throws -> RedisDataDecoder._RedisDataDecodingState {
        var buffer = allocator.buffer(capacity: input.count)
        buffer.write(bytes: input)

        var position = 1 // "trim" token

        return try RedisDataDecoder()._parseBulkString(at: &position, from: buffer)
    }
}

// MARK: Array Parsing

extension RedisDataDecoderParsingTests {
    func testParsing_array_whenNull_returnsNil() {
        XCTAssertEqual(try parseTestArray("*-1\r\n"), .parsed)
    }

    func testParsing_array_whenEmpty_returnsEmpty() {
        XCTAssertEqual(try parseTestArray("*0\r\n"), .parsed)
    }

    func testParsing_array_handlesLargeSizes() {
        let range = 0..<1000
        var data = "*\(range.endIndex)\r\n".convertedToData()
        range.forEach { _ in
            data += "$5\r\n".convertedToData()
            data += Data(bytes: [0xaa, 0xbb, 0xcc, 0xab, 0xff])
            data += "\r\n".convertedToData()
        }

        XCTAssertEqual(try parseTestArray(data), .parsed)
    }

    func testParsing_array_handlesMixedTypes() {
        XCTAssertEqual(try parseTestArray("*3\r\n:3\r\n+OK\r\n$1\r\na\r\n"), .parsed)
    }

    func testParsing_array_handlesNullElements() {
        XCTAssertEqual(try parseTestArray("*3\r\n:3\r\n$-1\r\n:30\r\n"), .parsed)
    }

    func testParsing_array_handlesNestedArrays() {
        XCTAssertEqual(try parseTestArray("*2\r\n:3\r\n*2\r\n:30\r\n:15\r\n"), .parsed)
    }

    private func parseTestArray(_ input: String) throws -> RedisDataDecoder._RedisDataDecodingState {
        return try parseTestArray(input.convertedToData())
    }

    private func parseTestArray(_ input: Data) throws -> RedisDataDecoder._RedisDataDecodingState {
        var buffer = allocator.buffer(capacity: input.count)
        buffer.write(bytes: input)

        var position = 1 // "trim" token

        return try RedisDataDecoder()._parseArray(at: &position, from: buffer)
    }
}

extension RedisDataDecoderParsingTests {
    static var allTests = [
        ("testParsing_with_simpleString", testParsing_with_simpleString),
        ("testParsing_with_simpleString_recursively", testParsing_with_simpleString_recursively),
        ("testParsing_with_integer", testParsing_with_integer),
        ("testParsing_with_integer_recursively", testParsing_with_integer_recursively),
        ("testParsing_with_bulkString", testParsing_with_bulkString),
        ("testParsing_with_bulkString_recursively", testParsing_with_bulkString_recursively),
        ("testParsing_with_arrays", testParsing_with_arrays),
        ("testParsing_with_arrays_recursively", testParsing_with_arrays_recursively),
        ("testParsing_simpleString_missingEndings_returnsNil", testParsing_simpleString_missingEndings_returnsNil),
        ("testParsing_simpleString_withNoContent_returnsEmpty", testParsing_simpleString_withNoContent_returnsEmpty),
        ("testParsing_simpleString_withContent_returnsExpectedContent", testParsing_simpleString_withContent_returnsExpectedContent),
        ("testParsing_integer_missingEndings_returnsNil", testParsing_integer_missingEndings_returnsNil),
        ("testParsing_integer_withContent_returnsExpectedContent", testParsing_integer_withContent_returnsExpectedContent),
        ("testParsing_integer_handlesRecursion", testParsing_integer_handlesRecursion),
        ("testParsing_bulkString_handlesMissingEndings", testParsing_bulkString_handlesMissingEndings),
        ("testParsing_bulkString_withNoSize_returnsEmpty", testParsing_bulkString_withNoSize_returnsEmpty),
        ("testParsing_bulkString_withSize_returnsContent", testParsing_bulkString_withSize_returnsContent),
        ("testParsing_bulkString_withNull_returnsNil", testParsing_bulkString_withNull_returnsNil),
        ("testParsing_bulkString_handlesRawBytes", testParsing_bulkString_handlesRawBytes),
        ("testParsing_bulkString_handlesLargeSizes", testParsing_bulkString_handlesLargeSizes),
        ("testParsing_array_whenNull_returnsNil", testParsing_array_whenNull_returnsNil),
        ("testParsing_array_whenEmpty_returnsEmpty", testParsing_array_whenEmpty_returnsEmpty),
        ("testParsing_array_handlesLargeSizes", testParsing_array_handlesLargeSizes),
        ("testParsing_array_handlesMixedTypes", testParsing_array_handlesMixedTypes),
        ("testParsing_array_handlesNullElements", testParsing_array_handlesNullElements),
        ("testParsing_array_handlesNestedArrays", testParsing_array_handlesNestedArrays),
    ]
}
