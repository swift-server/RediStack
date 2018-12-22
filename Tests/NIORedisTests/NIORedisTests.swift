@testable import NIORedis
import XCTest

final class NIORedisTests: XCTestCase {
    func test_makeConnection() {
        let redis = NIORedis(executionModel: .spawnThreads(1))
        defer { try? redis.terminate() }

        XCTAssertNoThrow(try redis.makeConnection().wait())
    }

    func test_command() throws {
        let redis = NIORedis(executionModel: .spawnThreads(1))
        defer { try? redis.terminate() }

        let connection = try redis.makeConnection().wait()
        let result = try connection.command("SADD", [.bulkString("key".convertedToData()), try 3.convertToRedisData()]).wait()
        XCTAssertNotNil(result.int)
        XCTAssertEqual(result.int, 1)
        try connection.command("DEL", [.bulkString("key".convertedToData())]).wait()
    }

    static var allTests = [
        ("test_makeConnection", test_makeConnection),
    ]
}
