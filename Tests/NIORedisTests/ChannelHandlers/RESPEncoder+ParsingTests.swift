import Foundation
import NIO
@testable import NIORedis
import XCTest

final class RESPEncoderParsingTests: XCTestCase {
    private let encoder = RESPEncoder()

    func testSimpleStrings() {
        XCTAssertTrue(testPass(input: .simpleString("Test1"), expected: "+Test1\r\n"))
        XCTAssertTrue(testPass(input: .simpleString("®in§³¾"), expected: "+®in§³¾\r\n"))
    }

    func testBulkStrings() {
        let bytes = Data([0x01, 0x02, 0x0a, 0x1b, 0xaa])
        XCTAssertTrue(testPass(input: .bulkString(bytes), expected: Data("$5\r\n".utf8) + bytes + Data("\r\n".utf8)))
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
            input: .array([ .integer(3), .simpleString("foo") ]),
            expected: "*2\r\n:3\r\n+foo\r\n"
        ))
        let bytes = Data([ 0x0a, 0x1a, 0x1b, 0xff ])
        XCTAssertTrue(testPass(
            input: .array([ .array([ .integer(10), .bulkString(bytes) ]) ]),
            expected: Data("*1\r\n*2\r\n:10\r\n$4\r\n".utf8) + bytes + Data("\r\n".utf8)
        ))
    }

    func testError() {
        let error = RedisError(identifier: "testError", reason: "Manual error")
        XCTAssertTrue(testPass(input: .error(error), expected: "-\(error.description)\r\n"))
    }

    func testNull() {
        XCTAssertTrue(testPass(input: .null, expected: "$-1\r\n"))
    }

    private func testPass(input: RESPValue, expected: Data) -> Bool {
        let allocator = ByteBufferAllocator()

        var comparisonBuffer = allocator.buffer(capacity: expected.count)
        comparisonBuffer.writeBytes(expected)

        var buffer = allocator.buffer(capacity: expected.count)
        encoder.encode(input.convertedToRESPValue(), into: &buffer)

        return buffer == comparisonBuffer
    }

    private func testPass(input: RESPValue, expected: String) -> Bool {
        let allocator = ByteBufferAllocator()

        var comparisonBuffer = allocator.buffer(capacity: expected.count)
        comparisonBuffer.writeString(expected)

        var buffer = allocator.buffer(capacity: expected.count)
        encoder.encode(input.convertedToRESPValue(), into: &buffer)

        return buffer == comparisonBuffer
    }
}

extension RESPEncoderParsingTests {
    static var allTests = [
        ("testSimpleStrings", testSimpleStrings),
        ("testBulkStrings", testBulkStrings),
        ("testIntegers", testIntegers),
        ("testArrays", testArrays),
        ("testError", testError),
        ("testNull", testNull),
    ]
}
