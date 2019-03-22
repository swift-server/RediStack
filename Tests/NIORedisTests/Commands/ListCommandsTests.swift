@testable import NIORedis
import XCTest

final class ListCommandsTests: XCTestCase {
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

    func test_llen() throws {
        var length = try connection.llen(of: #function).wait()
        XCTAssertEqual(length, 0)
        _ = try connection.lpush([30], to: #function).wait()
        length = try connection.llen(of: #function).wait()
        XCTAssertEqual(length, 1)
    }

    func test_lindex() throws {
        XCTAssertThrowsError(try connection.lindex(#function, index: 0).wait())
        _ = try connection.lpush([10], to: #function).wait()
        let element = try connection.lindex(#function, index: 0).wait()
        XCTAssertEqual(Int(element), 10)
    }

    func test_lset() throws {
        XCTAssertThrowsError(try connection.lset(#function, index: 0, to: 30).wait())
        _ = try connection.lpush([10], to: #function).wait()
        XCTAssertNoThrow(try connection.lset(#function, index: 0, to: 30).wait())
        let element = try connection.lindex(#function, index: 0).wait()
        XCTAssertEqual(Int(element), 30)
    }

    func test_lrem() throws {
        _ = try connection.lpush([10, 10, 20, 30, 10], to: #function).wait()
        var count = try connection.lrem(10, from: #function, count: 2).wait()
        XCTAssertEqual(count, 2)
        count = try connection.lrem(10, from: #function, count: 2).wait()
        XCTAssertEqual(count, 1)
    }

    func test_lrange() throws {
        var elements = try connection.lrange(of: #function, startIndex: 0, endIndex: 10).wait()
        XCTAssertEqual(elements.count, 0)

        _ = try connection.lpush([5, 4, 3, 2, 1], to: #function).wait()

        elements = try connection.lrange(of: #function, startIndex: 0, endIndex: 4).wait()
        XCTAssertEqual(elements.count, 5)
        XCTAssertEqual(Int(elements[0]), 1)
        XCTAssertEqual(Int(elements[4]), 5)

        elements = try connection.lrange(of: #function, startIndex: 2, endIndex: 0).wait()
        XCTAssertEqual(elements.count, 0)

        elements = try connection.lrange(of: #function, startIndex: 4, endIndex: 5).wait()
        XCTAssertEqual(elements.count, 1)

        elements = try connection.lrange(of: #function, startIndex: 0, endIndex: -4).wait()
        XCTAssertEqual(elements.count, 2)
    }

    func test_rpoplpush() throws {
        _ = try connection.lpush([10], to: "first").wait()
        _ = try connection.lpush([30], to: "second").wait()

        var element = try connection.rpoplpush(from: "first", to: "second").wait()
        XCTAssertEqual(Int(element), 10)
        XCTAssertEqual(try connection.llen(of: "first").wait(), 0)
        XCTAssertEqual(try connection.llen(of: "second").wait(), 2)

        element = try connection.rpoplpush(from: "second", to: "first").wait()
        XCTAssertEqual(Int(element), 30)
        XCTAssertEqual(try connection.llen(of: "second").wait(), 1)
    }

    func test_linsert() throws {
        _ = try connection.lpush([10], to: #function).wait()

        _ = try connection.linsert(20, into: #function, after: 10).wait()
        var elements = try connection.lrange(of: #function, startIndex: 0, endIndex: 1)
            .map { response in response.compactMap { Int($0) } }
            .wait()
        XCTAssertEqual(elements, [10, 20])

        _ = try connection.linsert(30, into: #function, before: 10).wait()
        elements = try connection.lrange(of: #function, startIndex: 0, endIndex: 2)
            .map { response in response.compactMap { Int($0) } }
            .wait()
        XCTAssertEqual(elements, [30, 10, 20])
    }

    func test_lpop() throws {
        _ = try connection.lpush([10, 20, 30], to: #function).wait()

        let element = try connection.lpop(from: #function).wait()
        XCTAssertNotNil(element)
        XCTAssertEqual(Int(element ?? .null), 30)
    }

    func test_lpush() throws {
        _ = try connection.rpush([10, 20, 30], to: #function).wait()

        let size = try connection.lpush([100], to: #function).wait()
        let element = try connection.lindex(#function, index: 0).mapFromRESP(to: Int.self).wait()
        XCTAssertEqual(size, 4)
        XCTAssertEqual(element, 100)
    }

    func test_lpushx() throws {
        var size = try connection.lpushx(10, to: #function).wait()
        XCTAssertEqual(size, 0)

        _ = try connection.lpush([10], to: #function).wait()

        size = try connection.lpushx(30, to: #function).wait()
        XCTAssertEqual(size, 2)
        let element = try connection.rpop(from: #function)
            .map { return Int($0 ?? .null) }
            .wait()
        XCTAssertEqual(element, 10)
    }

    func test_rpop() throws {
        _ = try connection.lpush([10, 20, 30], to: #function).wait()

        let element = try connection.rpop(from: #function).wait()
        XCTAssertNotNil(element)
        XCTAssertEqual(Int(element ?? .null), 10)
    }

    func test_rpush() throws {
        _ = try connection.lpush([10, 20, 30], to: #function).wait()

        let size = try connection.rpush([100], to: #function).wait()
        let element = try connection.lindex(#function, index: 3).mapFromRESP(to: Int.self).wait()
        XCTAssertEqual(size, 4)
        XCTAssertEqual(element, 100)
    }

    func test_rpushx() throws {
        var size = try connection.rpushx(10, to: #function).wait()
        XCTAssertEqual(size, 0)

        _ = try connection.rpush([10], to: #function).wait()

        size = try connection.rpushx(30, to: #function).wait()
        XCTAssertEqual(size, 2)
        let element = try connection.lpop(from: #function)
            .map { return Int($0 ?? .null) }
            .wait()
        XCTAssertEqual(element, 10)
    }

    static var allTests = [
        ("test_llen", test_llen),
        ("test_lindex", test_lindex),
        ("test_lset", test_lset),
        ("test_lrem", test_lrem),
        ("test_lrange", test_lrange),
        ("test_rpoplpush", test_rpoplpush),
        ("test_linsert", test_linsert),
        ("test_lpop", test_lpop),
        ("test_lpush", test_lpush),
        ("test_lpushx", test_lpushx),
        ("test_rpop", test_rpop),
        ("test_rpush", test_rpush),
        ("test_rpushx", test_rpushx),
    ]
}
