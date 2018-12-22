import NIO
@testable import NIORedis
import XCTest

final class RedisDataEncoderTests: XCTestCase {
    private var encoder: RedisDataEncoder!
    private var allocator: ByteBufferAllocator!
    private var channel: EmbeddedChannel!

    override func setUp() {
        super.setUp()

        encoder = RedisDataEncoder()
        allocator = ByteBufferAllocator()
        channel = EmbeddedChannel()
        _ = try? channel.pipeline.add(handler: encoder).wait()
    }

    override func tearDown() {
        super.tearDown()

        _ = try? channel.finish()
    }

    func testSimpleStrings() throws {
        let simpleString1 = RedisData.simpleString("Test1")
        try runEncodePass(with: simpleString1) { XCTAssertEqual($0.readableBytes, 8) }
        XCTAssertNoThrow(try channel.writeOutbound(simpleString1))

        let simpleString2 = RedisData.simpleString("®in§³¾")
        try runEncodePass(with: simpleString2) { XCTAssertEqual($0.readableBytes, 13) }
        XCTAssertNoThrow(try channel.writeOutbound(simpleString2))
    }

    func testBulkStrings() throws {
        let bs1 = RedisData.bulkString(Data(bytes: [0x01, 0x02, 0x0a, 0x1b, 0xaa]))
        try runEncodePass(with: bs1) { XCTAssertEqual($0.readableBytes, 11) }
        XCTAssertNoThrow(try channel.writeOutbound(bs1))

        let bs2 = RedisData.bulkString("®in§³¾".convertedToData())
        try runEncodePass(with: bs2) { XCTAssertEqual($0.readableBytes, 17) }
        XCTAssertNoThrow(try channel.writeOutbound(bs2))

        let bs3 = RedisData.bulkString("".convertedToData())
        try runEncodePass(with: bs3) { XCTAssertEqual($0.readableBytes, 6) }
        XCTAssertNoThrow(try channel.writeOutbound(bs3))
    }

    func testIntegers() throws {
        let i1 = RedisData.integer(Int.min)
        try runEncodePass(with: i1) { XCTAssertEqual($0.readableBytes, 23) }
        XCTAssertNoThrow(try channel.writeOutbound(i1))

        let i2 = RedisData.integer(0)
        try runEncodePass(with: i2) { XCTAssertEqual($0.readableBytes, 4) }
        XCTAssertNoThrow(try channel.writeOutbound(i2))
    }

    func testArrays() throws {
        let a1 = RedisData.array([])
        try runEncodePass(with: a1) { XCTAssertEqual($0.readableBytes, 4) }
        XCTAssertNoThrow(try channel.writeOutbound(a1))

        let a2: RedisData = .array([.integer(3), .simpleString("foo")])
        try runEncodePass(with: a2) { XCTAssertEqual($0.readableBytes, 14) }
        XCTAssertNoThrow(try channel.writeOutbound(a2))

        let bytes = Data(bytes: [ 0x0a, 0x1a, 0x1b, 0xff ])
        let a3: RedisData = .array([.array([
            .integer(3),
            .bulkString(bytes)
        ])])
        try runEncodePass(with: a3) { XCTAssertEqual($0.readableBytes, 22) }
        XCTAssertNoThrow(try channel.writeOutbound(a3))
    }

    func testError() throws {
        let error = RedisError(identifier: "testError", reason: "Manual error")
        let data = RedisData.error(error)
        try runEncodePass(with: data) {
            XCTAssertEqual($0.readableBytes, "-\(error.description)\r\n".convertedToData().count)
        }
        XCTAssertNoThrow(try channel.writeOutbound(data))
    }

    func testNull() throws {
        let null = RedisData.null
        try runEncodePass(with: null) { XCTAssertEqual($0.readableBytes, 5) }
        XCTAssertNoThrow(try channel.writeOutbound(null))
    }

    private func runEncodePass(with input: RedisData, _ validation: (ByteBuffer) -> Void) throws {
        let context = try channel.pipeline.context(handler: encoder).wait()

        var buffer = allocator.buffer(capacity: 256)
        try encoder.encode(ctx: context, data: input, out: &buffer)
        validation(buffer)
    }
}

extension RedisDataEncoderTests {
    static var allTests = [
        ("testSimpleStrings", testSimpleStrings),
        ("testBulkStrings", testBulkStrings),
        ("testIntegers", testIntegers),
        ("testArrays", testArrays),
        ("testError", testError),
        ("testNull", testNull),
    ]
}
