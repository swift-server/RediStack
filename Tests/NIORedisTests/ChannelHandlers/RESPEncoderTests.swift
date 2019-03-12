import NIO
@testable import NIORedis
import XCTest

final class RESPEncoderTests: XCTestCase {
    private var encoder: RESPEncoder!
    private var allocator: ByteBufferAllocator!
    private var channel: EmbeddedChannel!

    override func setUp() {
        super.setUp()

        encoder = RESPEncoder()
        allocator = ByteBufferAllocator()
        channel = EmbeddedChannel()
        _ = try? channel.pipeline.addHandler(MessageToByteHandler(encoder)).wait()
    }

    override func tearDown() {
        super.tearDown()

        _ = try? channel.finish()
    }

    func testSimpleStrings() throws {
        let simpleString1 = RESPValue.simpleString("Test1")
        try runEncodePass(with: simpleString1) { XCTAssertEqual($0.readableBytes, 8) }
        XCTAssertNoThrow(try channel.writeOutbound(simpleString1))

        let simpleString2 = RESPValue.simpleString("®in§³¾")
        try runEncodePass(with: simpleString2) { XCTAssertEqual($0.readableBytes, 13) }
        XCTAssertNoThrow(try channel.writeOutbound(simpleString2))
    }

    func testBulkStrings() throws {
        let bs1 = RESPValue.bulkString(Data([0x01, 0x02, 0x0a, 0x1b, 0xaa]))
        try runEncodePass(with: bs1) { XCTAssertEqual($0.readableBytes, 11) }
        XCTAssertNoThrow(try channel.writeOutbound(bs1))

        let bs2 = RESPValue.bulkString("®in§³¾".convertedToData())
        try runEncodePass(with: bs2) { XCTAssertEqual($0.readableBytes, 17) }
        XCTAssertNoThrow(try channel.writeOutbound(bs2))

        let bs3 = RESPValue.bulkString("".convertedToData())
        try runEncodePass(with: bs3) { XCTAssertEqual($0.readableBytes, 6) }
        XCTAssertNoThrow(try channel.writeOutbound(bs3))
    }

    func testIntegers() throws {
        let i1 = RESPValue.integer(Int.min)
        try runEncodePass(with: i1) { XCTAssertEqual($0.readableBytes, 23) }
        XCTAssertNoThrow(try channel.writeOutbound(i1))

        let i2 = RESPValue.integer(0)
        try runEncodePass(with: i2) { XCTAssertEqual($0.readableBytes, 4) }
        XCTAssertNoThrow(try channel.writeOutbound(i2))
    }

    func testArrays() throws {
        let a1 = RESPValue.array([])
        try runEncodePass(with: a1) { XCTAssertEqual($0.readableBytes, 4) }
        XCTAssertNoThrow(try channel.writeOutbound(a1))

        let a2: RESPValue = .array([.integer(3), .simpleString("foo")])
        try runEncodePass(with: a2) { XCTAssertEqual($0.readableBytes, 14) }
        XCTAssertNoThrow(try channel.writeOutbound(a2))

        let bytes = Data([ 0x0a, 0x1a, 0x1b, 0xff ])
        let a3: RESPValue = .array([.array([
            .integer(3),
            .bulkString(bytes)
        ])])
        try runEncodePass(with: a3) { XCTAssertEqual($0.readableBytes, 22) }
        XCTAssertNoThrow(try channel.writeOutbound(a3))
    }

    func testError() throws {
        let error = RedisError(identifier: "testError", reason: "Manual error")
        let data = RESPValue.error(error)
        try runEncodePass(with: data) {
            XCTAssertEqual($0.readableBytes, "-\(error.description)\r\n".convertedToData().count)
        }
        XCTAssertNoThrow(try channel.writeOutbound(data))
    }

    func testNull() throws {
        let null = RESPValue.null
        try runEncodePass(with: null) { XCTAssertEqual($0.readableBytes, 5) }
        XCTAssertNoThrow(try channel.writeOutbound(null))
    }

    private func runEncodePass(with input: RESPValue, _ validation: (ByteBuffer) -> Void) throws {
        var buffer = allocator.buffer(capacity: 256)
        try encoder.encode(data: input, out: &buffer)
        validation(buffer)
    }
}

extension RESPEncoderTests {
    static var allTests = [
        ("testSimpleStrings", testSimpleStrings),
        ("testBulkStrings", testBulkStrings),
        ("testIntegers", testIntegers),
        ("testArrays", testArrays),
        ("testError", testError),
        ("testNull", testNull),
    ]
}
