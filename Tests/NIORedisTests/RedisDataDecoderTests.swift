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
        XCTAssertEqual(try parseTestSimpleString("+ \r\n"), "")
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

        XCTAssertEqual(position, 5)

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

// MARK: Message Parsing

extension RedisDataDecoderTests {
    func testParsing_with_simpleString() throws {
        let testString = "+OK\r"
        var buffer = allocator.buffer(capacity: testString.count + 1)
        buffer.write(string: testString)

        var position = 0

        XCTAssertEqual(try parseTestSample(startPosition: &position, from: buffer), .notYetParsed)

        buffer.write(string: "\n")
        position = 0 // reset

        XCTAssertEqual(try parseTestSample(startPosition: &position, from: buffer), .parsed)
    }

    func testParsing_with_simpleString_recursively() throws {
        let messageChunks = ["+OK\r", "\n+OTHER STRING\r", "\n+&t®in§³¾\r", "\n"]
        var buffer = allocator.buffer(capacity: messageChunks.joined().count)
        buffer.write(string: "+OK\r")

        var position = 0

        XCTAssertEqual(try parseTestSample(startPosition: &position, from: buffer), .notYetParsed)

        for index in 1..<messageChunks.count {
            position = 0

            buffer.write(string: messageChunks[index])

            XCTAssertEqual(try parseTestSample(startPosition: &position, from: buffer), .parsed)

            _ = buffer.readBytes(length: position)
            
            XCTAssertEqual(try parseTestSample(startPosition: &position, from: buffer), .notYetParsed)
        }
    }

    private func parseTestSample(
        startPosition position: inout Int,
        from buffer: ByteBuffer
    ) throws -> RedisDataDecoder._PartialRedisData {
        return try RedisDataDecoder()._parse(at: &position, from: buffer)
    }
}

extension RedisDataDecoderTests {
    static var allTests = [
        ("testParsing_simpleString_missingEndings_returnsNil", testParsing_simpleString_missingEndings_returnsNil),
        ("testParsing_simpleString_withNoContent_returnsEmpty", testParsing_simpleString_withNoContent_returnsEmpty),
        ("testParsing_simpleString_handlesRecursion", testParsing_simpleString_withContent_returnsExpectedContent),
        ("testParsing_simpleString_handlesRecursion", testParsing_simpleString_handlesRecursion),
    ]
}
