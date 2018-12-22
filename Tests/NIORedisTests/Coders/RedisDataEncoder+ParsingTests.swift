import Foundation
import NIO
@testable import NIORedis
import XCTest

final class RedisDataEncoderParsingTests: XCTestCase {
    private let encoder = RedisDataEncoder()

    func testSimpleStrings() {
        XCTAssertEqual(
            encoder._encode(data: .simpleString("Test1")),
            "+Test1\r\n".convertedToData()
        )
        XCTAssertEqual(
            encoder._encode(data: .simpleString("®in§³¾")),
            "+®in§³¾\r\n".convertedToData()
        )
    }

    func testBulkStrings() {
        let t1 = Data(bytes: [0x01, 0x02, 0x0a, 0x1b, 0xaa])
        XCTAssertEqual(
            encoder._encode(data: .bulkString(t1)),
            "$5\r\n".convertedToData() + t1 + "\r\n".convertedToData()
        )
        let t2 = "®in§³¾".convertedToData()
        XCTAssertEqual(
            encoder._encode(data: .bulkString(t2)),
            "$10\r\n".convertedToData() + t2 + "\r\n".convertedToData()
        )
        let t3 = "".convertedToData()
        XCTAssertEqual(
            encoder._encode(data: .bulkString(t3)),
            "$0\r\n\r\n".convertedToData()
        )
    }

    func testIntegers() {
        XCTAssertEqual(
            encoder._encode(data: .integer(Int.min)),
            ":\(Int.min)\r\n".convertedToData()
        )
        XCTAssertEqual(
            encoder._encode(data: .integer(0)),
            ":0\r\n".convertedToData()
        )
    }

    func testArrays() {
        XCTAssertEqual(
            encoder._encode(data: .array([])),
            "*0\r\n".convertedToData()
        )
        let a1: RedisData = .array([.integer(3), .simpleString("foo")])
        XCTAssertEqual(
            encoder._encode(data: a1),
            "*2\r\n:3\r\n+foo\r\n".convertedToData()
        )
        let bytes = Data(bytes: [ 0x0a, 0x1a, 0x1b, 0xff ])
        let a2: RedisData = .array([.array([
            .integer(3),
            .bulkString(bytes)
        ])])
        XCTAssertEqual(
            encoder._encode(data: a2),
            "*1\r\n*2\r\n:3\r\n$4\r\n".convertedToData() + bytes + "\r\n".convertedToData()
        )
    }

    func testError() {
        let error = RedisError(identifier: "testError", reason: "Manual error")
        let result = encoder._encode(data: .error(error))
        XCTAssertEqual(result, "-\(error.description)\r\n".convertedToData())
    }

    func testNull() {
        XCTAssertEqual(encoder._encode(data: .null), "$-1\r\n".convertedToData())
    }
}

extension RedisDataEncoderParsingTests {
    static var allTests = [
        ("testSimpleStrings", testSimpleStrings),
        ("testBulkStrings", testBulkStrings),
        ("testIntegers", testIntegers),
        ("testArrays", testArrays),
        ("testError", testError),
        ("testNull", testNull),
    ]
}
