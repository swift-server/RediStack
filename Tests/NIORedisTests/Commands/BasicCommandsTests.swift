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
        _ = try? connection?.send(command: "FLUSHALL").wait()
        connection?.close()
        connection = nil
    }

    func test_select() {
        XCTAssertNoThrow(try connection?.select(database: 3).wait())
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

        try connection?.select(database: 1).wait()
        var second = try connection?.get("first").wait()
        XCTAssertEqual(second, nil)

        try connection?.set("second", to: "100").wait()
        second = try connection?.get("second").wait()
        XCTAssertEqual(second, "100")

        let success = try connection?.swapdb(firstIndex: 0, secondIndex: 1).wait()
        XCTAssertEqual(success, true)

        second = try connection?.get("first").wait()
        XCTAssertEqual(second, "3")

        try connection?.select(database: 0).wait()
        first = try connection?.get("second").wait()
        XCTAssertEqual(first, "100")
    }

    func test_increment() throws {
        var result = try connection?.increment(#function).wait()
        XCTAssertEqual(result, 1)
        result = try connection?.increment(#function).wait()
        XCTAssertEqual(result, 2)
    }

    func test_incrementBy() throws {
        var result = try connection?.increment(#function, by: 10).wait()
        XCTAssertEqual(result, 10)
        result = try connection?.increment(#function, by: -3).wait()
        XCTAssertEqual(result, 7)
        result = try connection?.increment(#function, by: 0).wait()
        XCTAssertEqual(result, 7)
    }

    func test_incrementByFloat() throws {
        var float = try connection?.increment(#function, by: Float(3.0)).wait()
        XCTAssertEqual(float, 3.0)
        float = try connection?.increment(#function, by: Float(-10.135901)).wait()
        XCTAssertEqual(float, -7.135901)

        var double = try connection?.increment(#function, by: Double(10.2839)).wait()
        XCTAssertEqual(double, 3.147999)
        double = try connection?.increment(#function, by: Double(15.2938)).wait()
        XCTAssertEqual(double, 18.441799)
    }

    func test_decrement() throws {
        var result = try connection?.decrement(#function).wait()
        XCTAssertEqual(result, -1)
        result = try connection?.decrement(#function).wait()
        XCTAssertEqual(result, -2)
    }

    func test_decrementBy() throws {
        var result = try connection?.decrement(#function, by: -10).wait()
        XCTAssertEqual(result, 10)
        result = try connection?.decrement(#function, by: 3).wait()
        XCTAssertEqual(result, 7)
        result = try connection?.decrement(#function, by: 0).wait()
        XCTAssertEqual(result, 7)
    }

    func test_mget() throws {
        let keys = ["one", "two"]
        try keys.forEach { _ = try connection?.set($0, to: $0).wait() }

        let values = try connection?.mget(keys + ["empty"]).wait()
        XCTAssertEqual(values?.count, 3)
        XCTAssertEqual(values?[0].string, "one")
        XCTAssertEqual(values?[1].string, "two")
        XCTAssertEqual(values?[2].isNull, true)

        XCTAssertEqual(try connection?.mget(["empty", #function]).wait().count, 2)
    }

    func test_mset() throws {
        let data = [
            "first": 1,
            "second": 2
        ]
        XCTAssertNoThrow(try connection?.mset(data).wait())
        let values = try connection?.mget(["first", "second"]).wait().compactMap { $0.string }
        XCTAssertEqual(values?.count, 2)
        XCTAssertEqual(values?[0], "1")
        XCTAssertEqual(values?[1], "2")

        XCTAssertNoThrow(try connection?.mset(["first": 10]).wait())
        let val = try connection?.get("first").wait()
        XCTAssertEqual(val, "10")
    }

    func test_msetnx() throws {
        let data = [
            "first": 1,
            "second": 2
        ]
        var success = try connection?.msetnx(data).wait()
        XCTAssertEqual(success, true)

        success = try connection?.msetnx(["first": 10, "second": 20]).wait()
        XCTAssertEqual(success, false)

        let values = try connection?.mget(["first", "second"]).wait().compactMap { $0.string }
        XCTAssertEqual(values?[0], "1")
        XCTAssertEqual(values?[1], "2")
    }

    func test_scan() throws {
        var dataset: [String] = .init(repeating: "", count: 10)
        for index in 1...15 {
            let key = "key\(index)\(index % 2 == 0 ? "_even" : "_odd")"
            dataset.append(key)
            _ = try connection?.set(key, to: "\(index)").wait()
        }

        var (cursor, keys) = try connection?.scan(count: 5).wait() ?? (0, [])
        XCTAssertGreaterThanOrEqual(cursor, 0)
        XCTAssertGreaterThanOrEqual(keys.count, 5)

        (_, keys) = try connection?.scan(startingFrom: cursor, count: 8).wait() ?? (0, [])
        XCTAssertGreaterThanOrEqual(keys.count, 8)

        (cursor, keys) = try connection?.scan(matching: "*_odd").wait() ?? (0, [])
        XCTAssertGreaterThanOrEqual(cursor, 0)
        XCTAssertGreaterThanOrEqual(keys.count, 1)
        XCTAssertLessThanOrEqual(keys.count, 7)

        (cursor, keys) = try connection?.scan(matching: "*_even*").wait() ?? (0, [])
        XCTAssertGreaterThanOrEqual(cursor, 0)
        XCTAssertGreaterThanOrEqual(keys.count, 1)
        XCTAssertLessThanOrEqual(keys.count, 7)
    }

    static var allTests = [
        ("test_select", test_select),
        ("test_set", test_set),
        ("test_get", test_get),
        ("test_expire", test_expire),
        ("test_delete", test_delete),
        ("test_ping", test_ping),
        ("test_echo", test_echo),
        ("test_swapdb", test_swapdb),
        ("test_increment", test_increment),
        ("test_incrementBy", test_incrementBy),
        ("test_incrementByFloat", test_incrementByFloat),
        ("test_decrement", test_decrement),
        ("test_decrementBy", test_decrementBy),
        ("test_mget", test_mget),
        ("test_mset", test_mset),
        ("test_msetnx", test_msetnx),
        ("test_scan", test_scan),
    ]
}
