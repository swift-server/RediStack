import NIO
@testable import NIORedis
import XCTest

final class RESPDecoderTests: XCTestCase {
    private let decoder = RESPDecoder()
    private let allocator = ByteBufferAllocator()

    func test_error() throws {
        XCTAssertNil(try runTest("-ERR"))
        XCTAssertNil(try runTest("-ERR\r"))
        XCTAssertEqual(try runTest("-ERROR\r\n")?.error?.description.contains("ERROR"), true)

        let multiError: (RESPValue?, RESPValue?) = try runTest("-ERROR\r\n-OTHER ERROR\r\n")
        XCTAssertEqual(multiError.0?.error?.description.contains("ERROR"), true)
        XCTAssertEqual(multiError.1?.error?.description.contains("OTHER ERROR"), true)
    }

    func test_simpleString() throws {
        XCTAssertNil(try runTest("+OK"))
        XCTAssertNil(try runTest("+OK\r"))
        XCTAssertEqual(try runTest("+\r\n")?.string, "")
        XCTAssertEqual(try runTest("+OK\r\n")?.string, "OK")

        XCTAssertEqual(try runTest("+©ºmpl³x\r\n")?.string, "©ºmpl³x")

        let multiSimpleString: (RESPValue?, RESPValue?) = try runTest("+OK\r\n+OTHER STRINGS\r\n")
        XCTAssertEqual(multiSimpleString.0?.string, "OK")
        XCTAssertEqual(multiSimpleString.1?.string, "OTHER STRINGS")
    }

    func test_integer() throws {
        XCTAssertNil(try runTest(":100"))
        XCTAssertNil(try runTest(":100\r"))
        XCTAssertNil(try runTest(":\r"))
        XCTAssertEqual(try runTest(":0\r\n")?.int, 0)
        XCTAssertEqual(try runTest(":01\r\n")?.int, 1)
        XCTAssertEqual(try runTest(":1000\r\n")?.int, 1000)
        XCTAssertEqual(try runTest(":-9223372036854775807\r\n")?.int, -9223372036854775807)

        let multiInteger: (RESPValue?, RESPValue?) = try runTest(":9223372036854775807\r\n:99\r\n")
        XCTAssertEqual(multiInteger.0?.int, 9223372036854775807)
        XCTAssertEqual(multiInteger.1?.int, 99)
    }

    func test_bulkString() throws {
        XCTAssertNil(try runTest("$0"))
        XCTAssertNil(try runTest("$0\r"))
        XCTAssertNil(try runTest("$0\r\n\r"))
        XCTAssertNil(try runTest("$-1\r"))
        XCTAssertEqual(try runTest("$-1\r\n")?.isNull, true)
        XCTAssertEqual(try runTest("$0\r\n\r\n")?.string, "")
        XCTAssertNil(try runTest("$1\r\na\r"))
        XCTAssertEqual(try runTest("$1\r\na\r\n")?.string, "a")
        XCTAssertNil(try runTest("$3\r\nfoo\r"))
        XCTAssertEqual(try runTest("$3\r\nfoo\r\n")?.string, "foo")
        XCTAssertNil(try runTest("$3\r\nn³\r"))
        XCTAssertEqual(try runTest("$3\r\nn³\r\n")?.string, "n³")

        let str = "κόσμε"
        let strBytes = str.bytes
        let strInput = "$\(strBytes.count)\r\n\(str)\r\n"
        XCTAssertEqual(try runTest(strInput)?.string, str)
        XCTAssertEqual(try runTest(strInput)?.bytes, strBytes)

        let multiBulkString: (RESPValue?, RESPValue?) = try runTest("$-1\r\n$3\r\nn³\r\n")
        XCTAssertEqual(multiBulkString.0?.isNull, true)
        XCTAssertEqual(multiBulkString.1?.string, "n³")

        let rawBytes: [UInt8] = [0x00, 0x01, 0x02, 0x03, 0x0A, 0xff]
        let rawByteInput = "$\(rawBytes.count)\r\n".bytes + rawBytes + "\r\n".bytes
        XCTAssertEqual(try runTest(rawByteInput)?.bytes, rawBytes)
    }

    func test_array() throws {
        func runArrayTest(_ input: String) throws -> [RESPValue]? {
            return try runTest(input)?.array
        }

        XCTAssertNil(try runArrayTest("*0\r"))
        XCTAssertNil(try runArrayTest("*1\r\n+OK\r"))
        XCTAssertEqual(try runArrayTest("*0\r\n")?.count, 0)
        XCTAssertTrue(arraysAreEqual(
            try runArrayTest("*1\r\n$3\r\nfoo\r\n"),
            expected: [.bulkString("foo".bytes)]
        ))
        XCTAssertTrue(arraysAreEqual(
            try runArrayTest("*3\r\n+foo\r\n$3\r\nbar\r\n:3\r\n"),
            expected: [.simpleString("foo"), .bulkString("bar".bytes), .integer(3)]
        ))
        XCTAssertTrue(arraysAreEqual(
            try runArrayTest("*1\r\n*2\r\n+OK\r\n:1\r\n"),
            expected: [.array([ .simpleString("OK"), .integer(1) ])]
        ))
    }

    private func runTest(_ input: String) throws -> RESPValue? {
        return try runTest(input.bytes)
    }

    private func runTest(_ input: [UInt8]) throws -> RESPValue? {
        return try runTest(input).0
    }

    private func runTest(_ input: String) throws -> (RESPValue?, RESPValue?) {
        return try runTest(input.bytes)
    }

    private func runTest(_ input: [UInt8]) throws -> (RESPValue?, RESPValue?) {
        let embeddedChannel = EmbeddedChannel()
        defer { _ = try? embeddedChannel.finish() }
        let handler = ByteToMessageHandler(decoder)
        try embeddedChannel.pipeline.addHandler(handler).wait()
        var buffer = allocator.buffer(capacity: 256)
        buffer.writeBytes(input)
        try embeddedChannel.writeInbound(buffer)
        return try (embeddedChannel.readInbound(), embeddedChannel.readInbound())
    }

    private func arraysAreEqual(_ lhs: [RESPValue]?, expected right: [RESPValue]) -> Bool {
        guard
            let left = lhs,
            left.count == right.count
        else { return false }

        var arraysMatch = true

        left.enumerated().forEach {
            let (offset, decodedElement) = $0

            switch (decodedElement, right[offset]) {
            case (let .bulkString(decoded), let .bulkString(expected)): arraysMatch = decoded == expected
            case (let .simpleString(decoded), let .simpleString(expected)): arraysMatch = decoded == expected
            case (let .integer(decoded), let .integer(expected)): arraysMatch = decoded == expected
            case (let .error(decoded), let .error(expected)): arraysMatch = decoded == expected
            case (.null, .null): break
            case (let .array(decoded), let .array(expected)): arraysMatch = arraysAreEqual(decoded, expected: expected)
            default:
                XCTFail("Array mismatch!")
                arraysMatch = false
            }
        }

        return arraysMatch
    }
}

// MARK: All Types

extension RESPDecoderTests {
    private struct AllData {
        static let expectedString = "string"
        static let expectedError = "ERROR"
        static let expectedBulkString = "aa"
        static let expectedInteger = -1000

        static var messages = [
            "+\(expectedString)\r\n",
            ":\(expectedInteger)\r\n",
            "-\(expectedError)\r\n",
            "$2\r\n\(expectedBulkString)\r\n",
            "$-1\r\n",
            "$0\r\n\r\n",
            "*3\r\n+\(expectedString)\r\n$2\r\n\(expectedBulkString)\r\n:\(expectedInteger)\r\n",
            "*1\r\n*1\r\n:\(expectedInteger)\r\n",
            "*0\r\n",
            "*-1\r\n"
        ]
    }

    func test_all() throws {
        let embeddedChannel = EmbeddedChannel()
        defer { _ = try? embeddedChannel.finish() }
        let handler = ByteToMessageHandler(decoder)
        try embeddedChannel.pipeline.addHandler(handler).wait()

        var buffer = allocator.buffer(capacity: 256)
        for message in AllData.messages {
            buffer.writeString(message)
        }

        try embeddedChannel.writeInbound(buffer)

        var results = [RESPValue?]()
        for _ in 0..<AllData.messages.count {
            results.append(try embeddedChannel.readInbound())
        }

        XCTAssertEqual(results[0]?.string, AllData.expectedString)
        XCTAssertEqual(results[1]?.int, AllData.expectedInteger)
        XCTAssertEqual(results[2]?.error?.description.contains(AllData.expectedError), true)

        XCTAssertEqual(results[3]?.string, AllData.expectedBulkString)
        XCTAssertEqual(results[3]?.bytes, AllData.expectedBulkString.bytes)

        XCTAssertEqual(results[4]?.isNull, true)

        XCTAssertEqual(results[5]?.bytes?.count, 0)
        XCTAssertEqual(results[5]?.string, "")

        XCTAssertEqual(results[6]?.array?.count, 3)
        XCTAssertTrue(arraysAreEqual(
            results[6]?.array,
            expected: [
                .simpleString(AllData.expectedString),
                .bulkString(AllData.expectedBulkString.bytes),
                .integer(AllData.expectedInteger)
            ]
        ))

        XCTAssertEqual(results[7]?.array?.count, 1)
        XCTAssertTrue(arraysAreEqual(
            results[7]?.array,
            expected: [.array([.integer(AllData.expectedInteger)])]
        ))

        XCTAssertEqual(results[8]?.array?.count, 0)
        XCTAssertEqual(results[9]?.isNull, true)
    }
}

extension RESPDecoderTests {
    static var allTests = [
        ("test_error", test_error),
        ("test_simpleString", test_simpleString),
        ("test_integer", test_integer),
        ("test_bulkString", test_bulkString),
        ("test_array", test_array),
        ("test_all", test_all),
    ]
}

extension RedisError: Equatable {
    public static func == (lhs: RedisError, rhs: RedisError) -> Bool {
        return lhs.description == rhs.description
    }
}
