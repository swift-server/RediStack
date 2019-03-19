@testable import NIORedis
import XCTest

final class BasicCommandsTests: XCTestCase {
    private let redis = RedisDriver(ownershipModel: .internal(threadCount: 1))
    deinit { try? redis.terminate() }

    private var connection: RedisConnection?

    override func setUp() {
        do {
            connection = try redis.makeConnection().wait()
        } catch {
            XCTFail("Failed to create NIORedisConnection!")
        }
    }

    override func tearDown() {
        _ = try? connection?.command("FLUSHALL").wait()
        connection?.close()
        connection = nil
    }

    func test_select() {
        XCTAssertNoThrow(try connection?.select(3).wait())
    }

    func test_delete() throws {
        let keys = [ #function + "1", #function + "2", #function + "3" ]
        try connection?.set(keys[0], to: "value").wait()
        try connection?.set(keys[1], to: "value").wait()
        try connection?.set(keys[2], to: "value").wait()

        let first = try connection?.delete(keys[0]).wait()
        XCTAssertEqual(first, 1)

        let second = try connection?.delete(keys[0]).wait()
        XCTAssertEqual(second, 0)

        let third = try connection?.delete(keys[1], keys[2]).wait()
        XCTAssertEqual(third, 2)
    }

    func test_set() {
        XCTAssertNoThrow(try connection?.set(#function, to: "value").wait())
    }

    func test_get() throws {
        try connection?.set(#function, to: "value").wait()
        let result = try connection?.get(#function).wait()
        XCTAssertEqual(result, "value")
    }

    func test_expire() throws {
        try connection?.set(#function, to: "value").wait()
        let before = try connection?.get(#function).wait()
        XCTAssertNotNil(before)

        let result = try connection?.expire(#function, after: 0).wait()
        XCTAssertEqual(result, true)

        let after = try connection?.get(#function).wait()
        XCTAssertNil(after)
    }

    func test_ping() throws {
        let first = try connection?.ping().wait()
        XCTAssertEqual(first, "PONG")

        let second = try connection?.ping(with: "My message").wait()
        XCTAssertEqual(second, "My message")
    }

    func test_echo() throws {
        let response = try connection?.echo("FIZZ_BUZZ").wait()
        XCTAssertEqual(response, "FIZZ_BUZZ")
    }

    func test_swapdb() throws {
        try connection?.set("first", to: "3").wait()
        var first = try connection?.get("first").wait()
        XCTAssertEqual(first, "3")

        try connection?.select(1).wait()
        var second = try connection?.get("first").wait()
        XCTAssertEqual(second, nil)

        try connection?.set("second", to: "100").wait()
        second = try connection?.get("second").wait()
        XCTAssertEqual(second, "100")

        let success = try connection?.swapdb(firstIndex: 0, secondIndex: 1).wait()
        XCTAssertEqual(success, true)

        second = try connection?.get("first").wait()
        XCTAssertEqual(second, "3")

        try connection?.select(0).wait()
        first = try connection?.get("second").wait()
        XCTAssertEqual(first, "100")
    }

    static var allTests = [
        ("test_select", test_select),
        ("test_set", test_set),
        ("test_get", test_get),
        ("test_expire", test_expire),
        ("test_delete", test_delete),
        ("test_ping", test_ping),
        ("test_echo", test_echo),
    ]
}
