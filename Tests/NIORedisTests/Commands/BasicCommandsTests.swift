@testable import NIORedis
import XCTest

final class BasicCommandsTests: XCTestCase {
    private let redis = NIORedis(executionModel: .spawnThreads(1))
    deinit { try? redis.terminate() }

    private var connection: NIORedisConnection?

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

    static var allTests = [
        ("test_select", test_select),
        ("test_set", test_set),
        ("test_get", test_get),
        ("test_expire", test_expire),
        ("test_delete", test_delete),
    ]
}
