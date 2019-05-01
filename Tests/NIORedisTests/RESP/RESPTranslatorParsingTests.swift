import Foundation
import NIO
@testable import NIORedis
import XCTest

final class RESPTranslatorParsingTests: XCTestCase {
    private let allocator = ByteBufferAllocator()

    private func runParse(
        offset: Int = 1,
        using block: (inout Int, inout ByteBuffer) throws -> RESPValue?
    ) -> RESPValue? {
        var buffer = allocator.buffer(capacity: 30)
        var position = offset
        do { return try block(&position, &buffer) }
        catch { return nil }
    }

    func testParsing_with_simpleString() {
        let string = parseTest_singleValue(input: "+OK\r\n")?.string
        XCTAssertEqual(string, "OK")
    }

    func testParsing_with_simpleString_multiple() throws {
        let result = try parseTest_twoValues(withChunks: ["+OK\r", "\n+&t®in§³¾\r", "\n"])
        XCTAssertTrue(result.0?.string == "OK")
        XCTAssertTrue(result.1?.string == "&t®in§³¾")
    }

    func testParsing_with_integer() {
        let integer = parseTest_singleValue(input: ":300\r\n")?.int
        XCTAssertEqual(integer, 300)
    }

    func testParsing_with_integer_multiple() throws {
        let result = try parseTest_twoValues(withChunks: [":300\r", "\n:\(Int.min)\r", "\n:"])
        XCTAssertTrue(result.0?.int == 300)
        XCTAssertTrue(result.1?.int == Int.min)
    }

    func testParsing_with_bulkString() {
        XCTAssertEqual(parseTest_singleValue(input: "$-1\r\n")?.isNull, true)
        XCTAssertEqual(parseTest_singleValue(input: "$0\r\n\r\n")?.string, "")
        XCTAssertEqual(parseTest_singleValue(input: "$1\r\n!\r\n")?.string, "!")
        XCTAssertEqual(
            parseTest_singleValue(input: "$1\r\n".bytes + [0xa3] + "\r\n".bytes)?.bytes,
            [0xa3]
        )
        XCTAssertEqual(
            parseTest_singleValue(input: "$1\r\n".bytes + [0xba] + "\r\n".bytes)?.bytes,
            [0xba]
        )
    }

    func testParsing_with_bulkString_multiple() throws {
        let t1 = try parseTest_twoValues(withChunks: ["$3\r", "\naaa\r\n$", "4\r\nnio!\r\n"])
        XCTAssertTrue(t1.0?.bytes?.count == 3)
        XCTAssertTrue(t1.1?.bytes?.count == 4)

        let chunks: [[UInt8]] = [
            "$3\r".bytes,
            "\n".bytes + [0xAA, 0xA3, 0xFF] + "\r\n$".bytes,
            "4\r\n".bytes + [0xbb, 0x3a, 0xba, 0xFF] + "\r\n".bytes
        ]
        let t2 = try parseTest_twoValues(withChunks: chunks)
        XCTAssertTrue(t2.0?.bytes?.count == 3)
        XCTAssertTrue(t2.1?.bytes?.count == 4)
    }

    func testParsing_with_arrays() {
        XCTAssertEqual(parseTest_singleValue(input: "*1\r\n+!\r\n")?.array?.count, 1)
        XCTAssertEqual(parseTest_singleValue(input: "*2\r\n*1\r\n:1\r\n:3\r\n")?.array?.count, 2)
        XCTAssertEqual(parseTest_singleValue(input: "*0\r\n".bytes)?.array?.count, 0)
        XCTAssertNil(parseTest_singleValue(input: "*-1\r\n".bytes)?.array)
    }

    func testParsing_with_arrays_multiple() throws {
        let t1 = try parseTest_twoValues(withChunks: ["*2\r", "\n+a\r\n+a\r\n*", "0\r\n"])
        XCTAssertTrue(t1.0?.array?.count == 2)
        XCTAssertTrue(t1.1?.array?.count == 0)

        let t2 = try parseTest_twoValues(withChunks: [
            "*-1\r".bytes,
            "\n".bytes,
            "*1\r".bytes,
            "\n+£\r\n".bytes
        ])
        XCTAssertTrue(t2.0?.array == nil)
        XCTAssertTrue(t2.1?.array?.count == 1)
    }

    func testParsing_withInvalidSymbol_throws() {
        _ = runParse(offset: 0) { position, buffer in
            buffer.writeString("&3\r\n")
            do {
                _ = try RESPTranslator.parseBytes(&buffer, fromIndex: &position)
                XCTFail("parse(at:from:) did not throw an expected error!")
            }
            catch { XCTAssertTrue(error is RESPTranslator.ParsingError) }

            return nil
        }
    }

    func testParsing_error() {
        let expectedContent = "ERR unknown command 'foobar'"
        let testString = "-\(expectedContent)\r\n"
        let result = runParse(offset: 0) { position, buffer in
            buffer.writeString(testString)
            guard
                case let .parsed(data) = try RESPTranslator.parseBytes(&buffer, fromIndex: &position),
                case .error = data
            else { return nil }

            return data
        }
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.error?.message.contains(expectedContent), true)
    }

    /// See parse_Test_singleValue(input:) String
    private func parseTest_singleValue(input: String) -> RESPValue? {
        return parseTest_singleValue(input: input.bytes)
    }

    /// Takes a collection of bytes representing a complete message and returns the data
    private func parseTest_singleValue(input: [UInt8]) -> RESPValue? {
        return runParse(offset: 0) { position, buffer in
            buffer.writeBytes(input)
            guard
                case let .parsed(result)? = try? RESPTranslator.parseBytes(&buffer, fromIndex: &position)
            else { return nil }
            return result
        }
    }

    /// See parseTest_recursive(withCunks:) [Data]
    private func parseTest_twoValues(withChunks messageChunks: [String]) throws -> (RESPValue?, RESPValue?) {
        return try parseTest_twoValues(withChunks: messageChunks.map({ $0.bytes }))
    }

    /// Takes a collection of incomplete byte messages that produce exactly two decoded RESPValue.
    /// The expected pattern of messages should be [incomplete, remaining, incomplete, remaining]
    /// - Returns: The first and second decoded data
    private func parseTest_twoValues(withChunks messageChunks: [[UInt8]]) throws -> (RESPValue?, RESPValue?) {
        var buffer = allocator.buffer(capacity: messageChunks.joined().count)

        for chunk in messageChunks {
            buffer.writeBytes(chunk)
        }

        var position = 0
        let p1 = try RESPTranslator.parseBytes(&buffer, fromIndex: &position)
        buffer.moveReaderIndex(forwardBy: position)
        position = 0
        let p2 = try RESPTranslator.parseBytes(&buffer, fromIndex: &position)

        guard
            case .parsed(let first) = p1,
            case .parsed(let second) = p2
        else {
            return (nil, nil)
        }

        return (first, second)
    }
}

// MARK: Simple String Parsing

extension RESPTranslatorParsingTests {
    func testParsing_simpleString_missingEndings_returnsNil() throws {
        XCTAssertNil(try parseTestSimpleString("+OK"))
        XCTAssertNil(try parseTestSimpleString("+OK\r"))
    }

    func testParsing_simpleString_withNoContent_returnsEmpty() throws {
        XCTAssertEqual(try parseTestSimpleString("+\r\n"), "")
    }

    func testParsing_simpleString_withContent_returnsExpectedContent() throws {
        XCTAssertEqual(try parseTestSimpleString("+ \r\n"), " ")
        XCTAssertEqual(try parseTestSimpleString("+OK\r\n"), "OK")
        XCTAssertEqual(try parseTestSimpleString("+OK\r\n+OTHER STRING\r\n"), "OK")
        XCTAssertEqual(try parseTestSimpleString("+&t®in§³¾\r\n"), "&t®in§³¾")
    }

    func testParsing_simpleString_handlesRecursion() throws {
        _ = runParse { position, buffer in
            let testString = "+OK\r\n+OTHER STRING\r\n"
            buffer.writeString(testString)

            _ = RESPTranslator.parseSimpleString(&buffer, &position)

            XCTAssertEqual(position, 5) // position of the 2nd '+'

            position += 1 // "trim" next token

            XCTAssertEqual(RESPTranslator.parseSimpleString(&buffer, &position), "OTHER STRING".byteBuffer)
            XCTAssertEqual(position, 25)

            return nil
        }
    }

    private func parseTestSimpleString(_ input: String) throws -> String? {
        return runParse { position, buffer in
            buffer.writeString(input)
            guard let string = RESPTranslator.parseSimpleString(&buffer, &position) else { return nil }
            return .simpleString(string)
        }?.string
    }
}

// MARK: Integer Parsing

extension RESPTranslatorParsingTests {
    func testParsing_integer_missingEndings_returnsNil() throws {
        XCTAssertNil(try parseTestInteger(":\r"))
        XCTAssertNil(try parseTestInteger(":\n"))
    }

    func testParsing_integer_withContent_returnsExpectedContent() throws {
        XCTAssertEqual(try parseTestInteger(":100\r\n"), 100)
        XCTAssertEqual(try parseTestInteger(":-100\r\n"), -100)
        XCTAssertEqual(try parseTestInteger(":-9223372036854775807\r\n"), -9223372036854775807)
        XCTAssertEqual(try parseTestInteger(":9223372036854775807\r\n"), 9223372036854775807)
    }

    func testParsing_integer_handlesRecursion() throws {
        _ = runParse { position, buffer in
            let testString = ":1\r\n:300\r\n"
            buffer.writeString(testString)

            _ = RESPTranslator.parseInteger(&buffer, &position)

            XCTAssertEqual(position, 4) // position of the next ':'

            position += 1 // "trim" next token

            XCTAssertEqual(RESPTranslator.parseInteger(&buffer, &position), 300)
            XCTAssertEqual(position, 14)

            return nil
        }
    }

    private func parseTestInteger(_ input: String) throws -> Int? {
        return runParse { position, buffer in
            buffer.writeString(input)
            guard let int = RESPTranslator.parseInteger(&buffer, &position) else { return nil }
            return .integer(int)
        }?.int
    }
}

// MARK: BulkString Parsing

extension RESPTranslatorParsingTests {
    func testParsing_bulkString_handlesMissingEndings() throws {
        for message in ["$6", "$6\r\n", "$6\r\nabcdef", "$0\r\n"]  {
            XCTAssertNil(parseTestBulkString(message))
        }
    }

    func testParsing_bulkString_withNoSize_returnsEmpty() throws {
        let result = parseTestBulkString("$0\r\n\r\n")
        XCTAssertEqual(result?.bytes?.count, 0)
    }

    func testParsing_bulkString_withSize_returnsContent() throws {
        let result = parseTestBulkString("$1\r\n1\r\n")
        XCTAssertEqual(result?.bytes?.count, 1)
    }

    func testParsing_bulkString_withNull_returnsNil() throws {
        let result = parseTestBulkString("$-1\r\n")
        XCTAssertEqual(result?.isNull, true)
    }

    func testParsing_bulkString_handlesRawBytes() throws {
        let bytes: [UInt8] = [0x00, 0x01, 0x02, 0x03, 0x0A, 0xFF]
        let allBytes = "$\(bytes.count)\r\n".bytes + bytes + "\r\n".bytes

        let result = parseTestBulkString(allBytes)

        XCTAssertEqual(result?.bytes?.count, bytes.count)
    }

    private func parseTestBulkString(_ input: String) -> RESPValue? {
        return parseTestBulkString(input.bytes)
    }

    private func parseTestBulkString(_ input: [UInt8]) -> RESPValue? {
        return runParse { position, buffer in
            buffer.writeBytes(input)
            guard
                case let .parsed(result) = RESPTranslator.parseBulkString(&buffer, &position)
            else { return nil }
            return result
        }
    }
}

// MARK: Array Parsing

extension RESPTranslatorParsingTests {
    func testParsing_array_whenNull_returnsNil() {
        let result = parseTestArray("*-1\r\n")
        XCTAssertEqual(result?.isNull, true)
    }

    func testParsing_array_whenEmpty_returnsEmpty() {
        let result = parseTestArray("*0\r\n")
        XCTAssertEqual(result?.array?.count, 0)
    }

    func testParsing_array_handlesMixedTypes() {
        let result = parseTestArray("*3\r\n:3\r\n+OK\r\n$1\r\na\r\n")?.array
        XCTAssertEqual(result?.count, 3)
        XCTAssertEqual(result?[0].int, 3)
        XCTAssertEqual(result?[1].string, "OK")
        XCTAssertEqual(result?[2].bytes?.count, 1)
    }

    func testParsing_array_handlesNullElements() {
        let result = parseTestArray("*3\r\n:3\r\n$-1\r\n:30\r\n")?.array
        XCTAssertEqual(result?.count, 3)
        XCTAssertEqual(result?[0].int, 3)
        XCTAssertEqual(result?[1].isNull, true)
        XCTAssertEqual(result?[2].int, 30)
    }

    func testParsing_array_handlesNestedArrays() {
        let result = parseTestArray("*2\r\n:3\r\n*2\r\n:30\r\n:15\r\n")?.array
        XCTAssertEqual(result?.count, 2)
        XCTAssertEqual(result?[0].int, 3)
        let nested = result?[1].array
        XCTAssertEqual(nested?.count, 2)
        XCTAssertEqual(nested?[0].int, 30)
        XCTAssertEqual(nested?[1].int, 15)
    }

    private func parseTestArray(_ input: String) -> RESPValue? {
        return parseTestArray(input.bytes)
    }

    private func parseTestArray(_ input: [UInt8]) -> RESPValue? {
        return runParse { position, buffer in
            buffer.writeBytes(input)
            guard
                case let .parsed(result) = try RESPTranslator.parseArray(&buffer, &position)
            else { return nil }
            return result
        }
    }
}

extension RESPTranslatorParsingTests {
    static var allTests = [
        ("testParsing_with_simpleString", testParsing_with_simpleString),
        ("testParsing_with_simpleString_multiple", testParsing_with_simpleString_multiple),
        ("testParsing_with_integer", testParsing_with_integer),
        ("testParsing_with_integer_multiple", testParsing_with_integer_multiple),
        ("testParsing_with_bulkString", testParsing_with_bulkString),
        ("testParsing_with_bulkString_multiple", testParsing_with_bulkString_multiple),
        ("testParsing_with_arrays", testParsing_with_arrays),
        ("testParsing_with_arrays_multiple", testParsing_with_arrays_multiple),
        ("testParsing_withInvalidSymbol_throws", testParsing_withInvalidSymbol_throws),

        ("testParsing_simpleString_missingEndings_returnsNil", testParsing_simpleString_missingEndings_returnsNil),
        ("testParsing_simpleString_withNoContent_returnsEmpty", testParsing_simpleString_withNoContent_returnsEmpty),
        ("testParsing_simpleString_withContent_returnsExpectedContent", testParsing_simpleString_withContent_returnsExpectedContent),
        ("testParsing_simpleString_handlesRecursion", testParsing_simpleString_handlesRecursion),

        ("testParsing_integer_missingEndings_returnsNil", testParsing_integer_missingEndings_returnsNil),
        ("testParsing_integer_withContent_returnsExpectedContent", testParsing_integer_withContent_returnsExpectedContent),
        ("testParsing_integer_handlesRecursion", testParsing_integer_handlesRecursion),

        ("testParsing_bulkString_handlesMissingEndings", testParsing_bulkString_handlesMissingEndings),
        ("testParsing_bulkString_withNoSize_returnsEmpty", testParsing_bulkString_withNoSize_returnsEmpty),
        ("testParsing_bulkString_withSize_returnsContent", testParsing_bulkString_withSize_returnsContent),
        ("testParsing_bulkString_withNull_returnsNil", testParsing_bulkString_withNull_returnsNil),
        ("testParsing_bulkString_handlesRawBytes", testParsing_bulkString_handlesRawBytes),

        ("testParsing_array_whenNull_returnsNil", testParsing_array_whenNull_returnsNil),
        ("testParsing_array_whenEmpty_returnsEmpty", testParsing_array_whenEmpty_returnsEmpty),
        ("testParsing_array_handlesMixedTypes", testParsing_array_handlesMixedTypes),
        ("testParsing_array_handlesNullElements", testParsing_array_handlesNullElements),
        ("testParsing_array_handlesNestedArrays", testParsing_array_handlesNestedArrays),
    ]
}
