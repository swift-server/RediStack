@testable import NIORedis
import XCTest

final class SetCommandsTests: XCTestCase {
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

    func test_sadd() throws {
        let key = #function

        var insertCount = try connection?.sadd(key, items: [1, 2, 3]).wait()
        XCTAssertEqual(insertCount, 3)
        insertCount = try connection?.sadd(key, items: [3, 4, 5]).wait()
        XCTAssertEqual(insertCount, 2)
    }

    func test_smembers() throws {
        let key = #function
        let first = ["Hello", ","]
        let second = ["World", "!"]

        _ = try connection?.sadd(key, items: first).wait()
        var set = try connection?.smembers(key).wait()
        XCTAssertEqual(set?.array?.count, 2)

        _ = try connection?.sadd(key, items: first).wait()
        set = try connection?.smembers(key).wait()
        XCTAssertEqual(set?.array?.count, 2)

        _ = try connection?.sadd(key, items: second).wait()
        set = try connection?.smembers(key).wait()
        XCTAssertEqual(set?.array?.count, 4)
    }

    func test_sismember() throws {
        let key = #function

        _ = try connection?.sadd(key, items: ["Hello"]).wait()
        XCTAssertTrue(try connection?.sismember(key, item: "Hello").wait() ?? false)

        XCTAssertFalse(try connection?.sismember(key, item: 3).wait() ?? true)

        _ = try connection?.sadd(key, items: [3]).wait()
        XCTAssertTrue(try connection?.sismember(key, item: 3).wait() ?? false)
    }

    func test_scard() throws {
        let key = #function

        XCTAssertEqual(try connection?.scard(key).wait(), 0)
        _ = try connection?.sadd(key, items: [1, 2, 3]).wait()
        XCTAssertEqual(try connection?.scard(key).wait(), 3)
    }

    func test_srem() throws {
        let key = #function

        var removedCount = try connection?.srem(key, items: [1]).wait()
        XCTAssertEqual(removedCount, 0)

        _ = try connection?.sadd(key, items: [1]).wait()
        removedCount = try connection?.srem(key, items: [1]).wait()
        XCTAssertEqual(removedCount, 1)
    }

    func test_spop() throws {
        let key = #function

        var count = try connection?.scard(key).wait()
        var item = try connection?.spop(key).wait()
        XCTAssertEqual(count, 0)
        XCTAssertEqual(item?.isNull, true)

        _ = try connection?.sadd(key, items: ["Hello"]).wait()
        item = try connection?.spop(key).wait()
        XCTAssertEqual(item?.string, "Hello")
        count = try connection?.scard(key).wait()
        XCTAssertEqual(count, 0)
    }

    func test_srandmember() throws {
        let key = #function

        _ = try connection?.sadd(key, items: [1, 2, 3]).wait()
        XCTAssertEqual(try connection?.srandmember(key).wait().array?.count, 1)
        XCTAssertEqual(try connection?.srandmember(key, max: 4).wait().array?.count, 3)
        XCTAssertEqual(try connection?.srandmember(key, max: -4).wait().array?.count, 4)
    }

    func test_sdiff() throws {
        let key1 = #function
        let key2 = #file
        let key3 = key1 + key2

        _ = try connection?.sadd(key1, items: [1, 2, 3]).wait()
        _ = try connection?.sadd(key2, items: [3, 4, 5]).wait()
        _ = try connection?.sadd(key3, items: [2, 4]).wait()

        let diff1 = try connection?.sdiff(key1, key2).wait() ?? []
        XCTAssertEqual(diff1.count, 2)

        let diff2 = try connection?.sdiff(key1, key3).wait() ?? []
        XCTAssertEqual(diff2.count, 2)

        let diff3 = try connection?.sdiff(key1, key2, key3).wait() ?? []
        XCTAssertEqual(diff3.count, 1)

        let diff4 = try connection?.sdiff(key3, key1, key2).wait() ?? []
        XCTAssertEqual(diff4.count, 0)
    }

    func test_sdiffstore() throws {
        let key1 = #function
        let key2 = #file
        let key3 = key1 + key2

        _ = try connection?.sadd(key1, items: [1, 2, 3]).wait()
        _ = try connection?.sadd(key2, items: [3, 4, 5]).wait()

        let diffCount = try connection?.sdiffstore(destination: key3, key1, key2).wait()
        XCTAssertEqual(diffCount, 2)
        let members = try connection?.smembers(key3).wait().array
        XCTAssertEqual(members?[0].string, "1")
        XCTAssertEqual(members?[1].string, "2")
    }

    func test_sinter() throws {
        let key1 = #function
        let key2 = #file
        let key3 = key1 + key2

        _ = try connection?.sadd(key1, items: [1, 2, 3]).wait()
        _ = try connection?.sadd(key2, items: [3, 4, 5]).wait()
        _ = try connection?.sadd(key3, items: [2, 4]).wait()

        let diff1 = try connection?.sinter(key1, key2).wait() ?? []
        XCTAssertEqual(diff1.count, 1)

        let diff2 = try connection?.sinter(key1, key3).wait() ?? []
        XCTAssertEqual(diff2.count, 1)

        let diff3 = try connection?.sinter(key1, key2, key3).wait() ?? []
        XCTAssertEqual(diff3.count, 0)

        let diff4 = try connection?.sinter(key3, key1, key2).wait() ?? []
        XCTAssertEqual(diff4.count, 0)
    }

    func test_sinterstore() throws {
        let key1 = #function
        let key2 = #file
        let key3 = key1 + key2

        _ = try connection?.sadd(key1, items: [1, 2, 3]).wait()
        _ = try connection?.sadd(key2, items: [3, 4, 5]).wait()

        let diffCount = try connection?.sinterstore(destination: key3, key1, key2).wait()
        XCTAssertEqual(diffCount, 1)
        XCTAssertEqual(try connection?.smembers(key3).wait().array?[0].string, "3")
    }

    func test_smove() throws {
        let key1 = #function
        let key2 = #file

        _ = try connection?.sadd(key1, items: [1, 2, 3]).wait()
        _ = try connection?.sadd(key2, items: [3, 4, 5]).wait()

        var didMove = try connection?.smove(item: 3, fromKey: key1, toKey: key2).wait()
        XCTAssertTrue(didMove ?? false)
        XCTAssertEqual(try connection?.scard(key1).wait(), 2)
        XCTAssertEqual(try connection?.scard(key2).wait(), 3)

        didMove = try connection?.smove(item: 2, fromKey: key1, toKey: key2).wait()
        XCTAssertTrue(didMove ?? false)
        XCTAssertEqual(try connection?.scard(key1).wait(), 1)
        XCTAssertEqual(try connection?.scard(key2).wait(), 4)

        didMove = try connection?.smove(item: 6, fromKey: key2, toKey: key1).wait()
        XCTAssertFalse(didMove ?? false)
    }

    func test_sunion() throws {
        let key1 = #function
        let key2 = #file
        let key3 = key1 + key2

        _ = try connection?.sadd(key1, items: [1, 2, 3]).wait()
        _ = try connection?.sadd(key2, items: [3, 4, 5]).wait()
        _ = try connection?.sadd(key3, items: [2, 4]).wait()

        let union1 = try connection?.sunion(key1, key2).wait() ?? []
        XCTAssertEqual(union1.count, 5)

        let union2 = try connection?.sunion(key2, key3).wait() ?? []
        XCTAssertEqual(union2.count, 4)

        let diff3 = try connection?.sunion(key1, key2, key3).wait() ?? []
        XCTAssertEqual(diff3.count, 5)
    }

    func test_sunionstore() throws {
        let key1 = #function
        let key2 = #file
        let key3 = key1 + key2

        _ = try connection?.sadd(key1, items: [1, 2, 3]).wait()
        _ = try connection?.sadd(key2, items: [2, 3, 4]).wait()

        let unionCount = try connection?.sunionstore(destination: key3, key1, key2).wait()
        XCTAssertEqual(unionCount, 4)
        let results = try connection?.smembers(key3).wait().array
        XCTAssertEqual(results?[0].string, "1")
        XCTAssertEqual(results?[1].string, "2")
        XCTAssertEqual(results?[2].string, "3")
        XCTAssertEqual(results?[3].string, "4")
    }

    func test_sscan() throws {
        let key = #function
        let dataset = [
            "Copenhagen, Denmark",
            "Roskilde, Denmark",
            "Herning, Denmark",
            "Kolding, Denmark",
            "Taastrup, Denmark",
            "London, England",
            "Bath, England",
            "Birmingham, England",
            "Cambridge, England",
            "Durham, England",
            "Seattle, United States",
            "Austin, United States",
            "New York City, United States",
            "San Francisco, United States",
            "Honolulu, United States"
        ]

        _ = try connection?.sadd(key, items: dataset).wait()

        var (cursor, results) = try connection?.sscan(key, count: 5).wait() ?? (0, [])
        XCTAssertGreaterThanOrEqual(cursor, 0)
        XCTAssertGreaterThanOrEqual(results.count, 5)

        (_, results) = try connection?.sscan(key, atPosition: cursor, count: 8).wait() ?? (0, [])
        XCTAssertGreaterThanOrEqual(results.count, 8)

        (cursor, results) = try connection?.sscan(key, matching: "*Denmark").wait() ?? (0, [])
        XCTAssertGreaterThanOrEqual(cursor, 0)
        XCTAssertGreaterThanOrEqual(results.count, 1)
        XCTAssertLessThanOrEqual(results.count, 5)

        (cursor, results) = try connection?.sscan(key, matching: "*ing*").wait() ?? (0, [])
        XCTAssertGreaterThanOrEqual(cursor, 0)
        XCTAssertGreaterThanOrEqual(results.count, 1)
        XCTAssertLessThanOrEqual(results.count, 3)
    }

    static var allTests = [
        ("test_sadd", test_sadd),
        ("test_smembers", test_smembers),
        ("test_sismember", test_sismember),
        ("test_scard", test_scard),
        ("test_srem", test_srem),
        ("test_spop", test_spop),
        ("test_srandmember", test_srandmember),
        ("test_sdiff", test_sdiff),
        ("test_sdiffstore", test_sdiffstore),
        ("test_sinter", test_sinter),
        ("test_sinterstore", test_sinterstore),
        ("test_smove", test_smove),
        ("test_sunion", test_sunion),
        ("test_sunionstore", test_sunionstore),
        ("test_sscan", test_sscan),
    ]
}
