import Foundation
import NIO
@testable import NIORedis
import XCTest

final class RedisDataDecoderTests: XCTestCase {
    private let allocator = ByteBufferAllocator()
}

// MARK: Simple String Parsing

extension RedisDataDecoderTests {
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

extension RedisDataDecoderTests {
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

// MARK: Message Parsing

extension RedisDataDecoderTests {
    func testParsing_with_simpleString() throws {
        try parseTest_singleValue(input: "+OK\r")
    }

    func testParsing_with_simpleString_recursively() throws {
        try parseTest_recursive(withChunks: ["+OK\r", "\n+OTHER STRING\r", "\n+&t®in§³¾\r", "\n"])
    }

    func testParsing_with_integer() throws {
        try parseTest_singleValue(input: ":300\r")
    }

    func testParsing_with_integer_recursively() throws {
        try parseTest_recursive(withChunks: [":300\r", "\n:-10135135\r", "\n:1\r", "\n"])
    }

    private func parseTest_singleValue(input: String) throws {
        let decoder = RedisDataDecoder()
        var buffer = allocator.buffer(capacity: input.count + 1)
        buffer.write(string: input)

        var position = 0

        XCTAssertEqual(try decoder._parse(at: &position, from: buffer), .notYetParsed)

        buffer.write(string: "\n")
        position = 0 // reset

        XCTAssertEqual(try decoder._parse(at: &position, from: buffer), .parsed)
    }

    private func parseTest_recursive(withChunks messageChunks: [String]) throws {
        let decoder = RedisDataDecoder()
        var buffer = allocator.buffer(capacity: messageChunks.joined().count)
        buffer.write(string: messageChunks[0])

        var position = 0

        XCTAssertEqual(try decoder._parse(at: &position, from: buffer), .notYetParsed)

        for index in 1..<messageChunks.count {
            position = 0

            buffer.write(string: messageChunks[index])

            XCTAssertEqual(try decoder._parse(at: &position, from: buffer), .parsed)

            _ = buffer.readBytes(length: position)

            XCTAssertEqual(try decoder._parse(at: &position, from: buffer), .notYetParsed)
        }
    }
}

extension RedisDataDecoderTests {
    static var allTests = [
        ("testParsing_simpleString_missingEndings_returnsNil", testParsing_simpleString_missingEndings_returnsNil),
        ("testParsing_simpleString_withNoContent_returnsEmpty", testParsing_simpleString_withNoContent_returnsEmpty),
        ("testParsing_simpleString_withContent_returnsExpectedContent", testParsing_simpleString_withContent_returnsExpectedContent),
        ("testParsing_simpleString_handlesRecursion", testParsing_simpleString_handlesRecursion),
        ("testParsing_integer_missingEndings_returnsNil", testParsing_integer_missingEndings_returnsNil),
        ("testParsing_integer_withContent_returnsExpectedContent", testParsing_integer_withContent_returnsExpectedContent),
        ("testParsing_integer_handlesRecursion", testParsing_integer_handlesRecursion),
        ("testParsing_with_simpleString", testParsing_with_simpleString),
        ("testParsing_with_simpleString_recursively", testParsing_with_simpleString_recursively),
        ("testParsing_with_integer", testParsing_with_integer),
        ("testParsing_with_integer_recursively", testParsing_with_integer_recursively),
    ]
}
