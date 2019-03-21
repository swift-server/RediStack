@testable import NIORedis
import XCTest

final class HashCommandsTests: XCTestCase {
    private let redis = RedisDriver(ownershipModel: .internal(threadCount: 1))
    deinit { try? redis.terminate() }

    private var connection: RedisConnection!

    override func setUp() {
        do {
            connection = try redis.makeConnection().wait()
        } catch {
            XCTFail("Failed to create NIORedisConnection!")
        }
    }

    override func tearDown() {
        _ = try? connection.send(command: "FLUSHALL").wait()
        connection.close()
        connection = nil
    }

    func test_hset() throws {
        var result = try connection.hset(#function, field: "test", to: "\(#line)").wait()
        XCTAssertTrue(result)
        result = try connection.hset(#function, field: "test", to: "\(#line)").wait()
        XCTAssertFalse(result)
    }

    func test_hmset() throws {
        XCTAssertNoThrow(try connection.hmset(#function, to: ["field": "30"]).wait())
        let value = try connection.hget(#function, field: "field").wait()
        XCTAssertEqual(value, "30")
    }

    func test_hsetnx() throws {
        var success = try connection.hsetnx(#function, field: "field", to: "foo").wait()
        XCTAssertTrue(success)
        success = try connection.hsetnx(#function, field: "field", to: "30").wait()
        XCTAssertFalse(success)

        let value = try connection.hget(#function, field: "field").wait()
        XCTAssertEqual(value, "foo")
    }

    func test_hget() throws {
        _ = try connection.hset(#function, field: "test", to: "30").wait()
        let value = try connection.hget(#function, field: "test").wait()
        XCTAssertEqual(value, "30")
    }

    func test_hmget() throws {
        _ = try connection.hmset(#function, to: ["first": "foo", "second": "bar"]).wait()
        let values = try connection.hmget(#function, fields: ["first", "second", "fake"]).wait()
        XCTAssertEqual(values[0], "foo")
        XCTAssertEqual(values[1], "bar")
        XCTAssertNil(values[2])
    }

    func test_hgetall() throws {
        let dataset = ["first": "foo", "second": "bar"]
        _ = try connection.hmset(#function, to: dataset).wait()
        let hashes = try connection.hgetall(from: #function).wait()
        XCTAssertEqual(hashes, dataset)
    }

    func test_hdel() throws {
        _ = try connection.hmset(#function, to: ["first": "foo", "second": "bar"]).wait()
        let count = try connection.hdel(#function, fields: ["first", "second", "fake"]).wait()
        XCTAssertEqual(count, 2)
    }

    func test_hexists() throws {
        var exists = try connection.hexists(#function, field: "foo").wait()
        XCTAssertFalse(exists)
        _ = try connection.hset(#function, field: "foo", to: "\(#line)").wait()
        exists = try connection.hexists(#function, field: "foo").wait()
        XCTAssertTrue(exists)
    }

    func test_hlen() throws {
        var count = try connection.hlen(of: #function).wait()
        XCTAssertEqual(count, 0)
        _ = try connection.hset(#function, field: "first", to: "\(#line)").wait()
        count = try connection.hlen(of: #function).wait()
        XCTAssertEqual(count, 1)
        _ = try connection.hset(#function, field: "second", to: "\(#line)").wait()
        count = try connection.hlen(of: #function).wait()
        XCTAssertEqual(count, 2)
    }

    func test_hstrlen() throws {
        _ = try connection.hset(#function, field: "first", to: "foo").wait()
        var size = try connection.hstrlen(of: #function, field: "first").wait()
        XCTAssertEqual(size, 3)
        _ = try connection.hset(#function, field: "second", to: "300").wait()
        size = try connection.hstrlen(of: #function, field: "second").wait()
        XCTAssertEqual(size, 3)
    }

    func test_hkeys() throws {
        let dataset = [
            "first": "3",
            "second": "foo"
        ]
        _ = try connection.hmset(#function, to: dataset).wait()
        let keys = try connection.hkeys(storedAt: #function).wait()
        XCTAssertEqual(Array(dataset.keys), keys)
    }

    func test_hvals() throws {
        let dataset = [
            "first": "3",
            "second": "foo"
        ]
        _ = try connection.hmset(#function, to: dataset).wait()
        let values = try connection.hvals(storedAt: #function).wait()
        XCTAssertEqual(Array(dataset.values), values)
    }

    func test_hincrby() throws {
        _ = try connection.hset(#function, field: "first", to: "3").wait()
        var value = try connection.hincrby(#function, field: "first", by: 10).wait()
        XCTAssertEqual(value, 13)
        value = try connection.hincrby(#function, field: "first", by: -15).wait()
        XCTAssertEqual(value, -2)
    }

    func test_hincrbyfloat() throws {
        _ = try connection.hset(#function, field: "first", to: "3.14").wait()

        let double = try connection.hincrbyfloat(#function, field: "first", by: Double(3.14)).wait()
        XCTAssertEqual(double, 6.28)

        let float = try connection.hincrbyfloat(#function, field: "first", by: Float(-10.23523)).wait()
        XCTAssertEqual(float, -3.95523)
    }

    func test_hscan() throws {
        var dataset: [String: String] = [:]
        for index in 1...15 {
            let key = "key\(index)\(index % 2 == 0 ? "_even" : "_odd")"
            dataset[key] = "\(index)"
        }
        _ = try connection.hmset(#function, to: dataset).wait()

        var (cursor, fields) = try connection.hscan(#function, count: 5).wait()
        XCTAssertGreaterThanOrEqual(cursor, 0)
        XCTAssertGreaterThanOrEqual(fields.count, 5)

        (_, fields) = try connection.hscan(#function, atPosition: cursor, count: 8).wait()
        XCTAssertGreaterThanOrEqual(fields.count, 8)

        (cursor, fields) = try connection.hscan(#function, matching: "*_odd").wait()
        XCTAssertGreaterThanOrEqual(cursor, 0)
        XCTAssertGreaterThanOrEqual(fields.count, 1)
        XCTAssertLessThanOrEqual(fields.count, 8)

        (cursor, fields) = try connection.hscan(#function, matching: "*_ev*").wait()
        XCTAssertGreaterThanOrEqual(cursor, 0)
        XCTAssertGreaterThanOrEqual(fields.count, 1)
        XCTAssertLessThanOrEqual(fields.count, 7)
    }

    static var allTests = [
        ("test_hset", test_hset),
        ("test_hmset", test_hmset),
        ("test_hsetnx", test_hsetnx),
        ("test_hget", test_hget),
        ("test_hmget", test_hmget),
        ("test_hgetall", test_hgetall),
        ("test_hdel", test_hdel),
        ("test_hexists", test_hexists),
        ("test_hlen", test_hlen),
        ("test_hstrlen", test_hstrlen),
        ("test_hkeys", test_hkeys),
        ("test_hvals", test_hvals),
        ("test_hincrby", test_hincrby),
        ("test_hincrbyfloat", test_hincrbyfloat),
        ("test_hscan", test_hscan),
    ]
}
