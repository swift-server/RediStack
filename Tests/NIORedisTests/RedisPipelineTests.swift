@testable import NIORedis
import XCTest

final class RedisPipelineTests: XCTestCase {
    private var redis: RedisDriver!
    private var connection: RedisConnection!

    override func setUp() {
        let redis = RedisDriver(ownershipModel: .internal(threadCount: 1))

        guard let connection = try? redis.makeConnection().wait() else {
            return XCTFail("Failed to create connection!")
        }

        self.redis = redis
        self.connection = connection
    }

    override func tearDown() {
        _ = try? connection.command("FLUSHALL").wait()
        connection.close()
        try? redis.terminate()
    }

    func test_enqueue() {
        let pipeline = connection.makePipeline()

        XCTAssertNoThrow(try pipeline.enqueue(command: "PING"))
        XCTAssertNoThrow(try pipeline.enqueue(command: "SET", arguments: ["KEY", 3]))
    }

    func test_executeFails() throws {
        let future = try connection.makePipeline()
            .enqueue(command: "GET")
            .execute()

        XCTAssertThrowsError(try future.wait())
    }

    func test_singleCommand() throws {
        let results = try connection.makePipeline()
            .enqueue(command: "PING")
            .execute()
            .wait()

        XCTAssertEqual(results[0].string, "PONG")
    }

    func test_multipleCommands() throws {
        let results = try connection.makePipeline()
            .enqueue(command: "PING")
            .enqueue(command: "SET", arguments: ["my_key", 3])
            .enqueue(command: "GET", arguments: ["my_key"])
            .execute()
            .wait()

        XCTAssertEqual(results[0].string, "PONG")
        XCTAssertEqual(results[1].string, "OK")
        XCTAssertEqual(results[2].data, "3".convertedToData())
    }

    func test_executeIsOrdered() throws {
        let results = try connection.makePipeline()
            .enqueue(command: "SET", arguments: ["key", 1])
            .enqueue(command: "INCR", arguments: ["key"])
            .enqueue(command: "DECR", arguments: ["key"])
            .enqueue(command: "INCRBY", arguments: ["key", 15])
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
