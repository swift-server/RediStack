import Foundation
import NIO
@testable import NIORedis
import XCTest

final class RESPTranslatorWritingTests: XCTestCase {
    private let encoder = RESPTranslator.self
    private let allocator = ByteBufferAllocator()

    func testSimpleStrings() {
        XCTAssertTrue(testPass(input: .simpleString("Test1".byteBuffer), expected: "+Test1\r\n"))
        XCTAssertTrue(testPass(input: .simpleString("®in§³¾".byteBuffer), expected: "+®in§³¾\r\n"))
    }

    func testBulkStrings() {
        let bytes: [UInt8] = [0x01, 0x02, 0x0a, 0x1b, 0xaa]
        var buffer = allocator.buffer(capacity: 5)
        buffer.writeBytes(bytes)
        XCTAssertTrue(testPass(input: .bulkString(buffer), expected: "$5\r\n".bytes + bytes + "\r\n".bytes))
        XCTAssertTrue(testPass(input: .init(bulk: "®in§³¾"), expected: "$10\r\n®in§³¾\r\n"))
        XCTAssertTrue(testPass(input: .init(bulk: ""), expected: "$0\r\n\r\n"))
    }

    func testIntegers() {
        XCTAssertTrue(testPass(input: .integer(Int.min), expected: ":\(Int.min)\r\n"))
        XCTAssertTrue(testPass(input: .integer(0), expected: ":0\r\n"))
    }

    func testArrays() {
        XCTAssertTrue(testPass(input: .array([]), expected: "*0\r\n"))
        XCTAssertTrue(testPass(
            input: .array([ .integer(3), .simpleString("foo".byteBuffer) ]),
            expected: "*2\r\n:3\r\n+foo\r\n"
        ))
        let bytes: [UInt8] = [ 0x0a, 0x1a, 0x1b, 0xff ]
        var buffer = allocator.buffer(capacity: 4)
        buffer.writeBytes(bytes)
        XCTAssertTrue(testPass(
            input: .array([ .array([ .integer(10), .bulkString(buffer) ]) ]),
            expected: "*1\r\n*2\r\n:10\r\n$4\r\n".bytes + bytes + "\r\n".bytes
        ))
    }

    func testError() {
        let error = RedisError(reason: "Manual error")
        XCTAssertTrue(testPass(input: .error(error), expected: "-\(error.message)\r\n"))
    }

    func testNull() {
        XCTAssertTrue(testPass(input: .null, expected: "$-1\r\n"))
    }

    private func testPass(input: RESPValue, expected: [UInt8]) -> Bool {
        let allocator = ByteBufferAllocator()

        var comparisonBuffer = allocator.buffer(capacity: expected.count)
        comparisonBuffer.writeBytes(expected)

        var buffer = allocator.buffer(capacity: expected.count)
        encoder.writeValue(input.convertedToRESPValue(), into: &buffer)

        return buffer == comparisonBuffer
    }

    private func testPass(input: RESPValue, expected: String) -> Bool {
        let allocator = ByteBufferAllocator()

        var comparisonBuffer = allocator.buffer(capacity: expected.count)
        comparisonBuffer.writeString(expected)

        var buffer = allocator.buffer(capacity: expected.count)
        encoder.writeValue(input.convertedToRESPValue(), into: &buffer)

        return buffer == comparisonBuffer
    }
}

extension RESPTranslatorWritingTests {
    static var allTests = [
        ("testSimpleStrings", testSimpleStrings),
        ("testBulkStrings", testBulkStrings),
        ("testIntegers", testIntegers),
        ("testArrays", testArrays),
        ("testError", testError),
        ("testNull", testNull),
    ]
}
