@testable import NIORedis
import XCTest

final class RedisPipelineTests: XCTestCase {
    private var connection: RedisConnection!

    override func setUp() {
        do {
            connection = try Redis.makeConnection().wait()
        } catch {
            XCTFail("Failed to create RedisConnection! \(error)")
        }
    }

    override func tearDown() {
        _ = try? connection.send(command: "FLUSHALL").wait()
        try? connection.close().wait()
        connection = nil
    }

    func test_enqueue() throws {
        let pipeline = connection.makePipeline()

        pipeline.enqueue { $0.send(command: "PING") }
        XCTAssertEqual(pipeline.count, 1)

        pipeline.enqueue { $0.send(command: "SET", with: ["KEY", 3]) }
        XCTAssertEqual(pipeline.count, 2)
    }

    func test_executeFails() throws {
        let future = connection.makePipeline()
            .enqueue { $0.send(command: "GET") }
            .execute()

        XCTAssertThrowsError(try future.wait())
    }

    func test_singleCommand() throws {
        let results = try connection.makePipeline()
            .enqueue { $0.send(command: "PING") }
            .execute()
            .wait()

        XCTAssertEqual(results[0].string, "PONG")
    }

    func test_multipleCommands() throws {
        let results = try connection.makePipeline()
            .enqueue { $0.send(command: "PING") }
            .enqueue { $0.set("my_key", to: "3") }
            .enqueue { $0.get("my_key") }
            .execute()
            .wait()

        XCTAssertEqual(results[0].string, "PONG")
        XCTAssertEqual(results[1].string, "OK")
        XCTAssertEqual(results[2].bytes, "3".bytes)
    }

    func test_executeIsOrdered() throws {
        let results = try connection.makePipeline()
            .enqueue { $0.set("key", to: "1") }
            .enqueue { $0.send(command: "INCR", with: ["key"]) }
            .enqueue { $0.send(command: "DECR", with: ["key"]) }
            .enqueue { $0.send(command: "INCRBY", with: ["key", 15]) }
            .execute()
            .wait()

        XCTAssertEqual(results[0].string, "OK")
        XCTAssertEqual(results[1].int, 2)
        XCTAssertEqual(results[2].int, 1)
        XCTAssertEqual(results[3].int, 16)
    }

    static var allTests = [
        ("test_enqueue", test_enqueue),
        ("test_executeFails", test_executeFails),
        ("test_singleCommand", test_singleCommand),
        ("test_multipleCommands", test_multipleCommands),
        ("test_executeIsOrdered", test_executeIsOrdered),
    ]
}
