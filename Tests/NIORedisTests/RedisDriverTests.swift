@testable import NIORedis
import XCTest

final class RedisDriverTests: XCTestCase {
    private var driver: RedisDriver!
    private var connection: RedisConnection!

    override func setUp() {
        let driver = RedisDriver(ownershipModel: .internal(threadCount: 1))

        guard let connection = try? driver.makeConnection().wait() else {
            return XCTFail("Failed to create a connection!")
        }

        self.driver = driver
        self.connection = connection
    }

    override func tearDown() {
        _ = connection.send(command: "FLUSHALL")
            .flatMap { _ in self.connection.close() }
            .map { _ in try? self.driver.terminate() }
    }

    func test_makeConnection() {
        XCTAssertNoThrow(try driver.makeConnection().wait().close())
    }

    func test_command_succeeds() throws {
        let result = try connection.send(command: "SADD", with: ["key", 3]).wait()

        XCTAssertNotNil(result.int)
        XCTAssertEqual(result.int, 1)
    }

    func test_command_fails() {
        let command = connection.send(command: "GET")

        XCTAssertThrowsError(try command.wait())
    }

    static var allTests = [
        ("test_makeConnection", test_makeConnection),
        ("test_command_succeeds", test_command_succeeds),
        ("test_command_fails", test_command_fails),
    ]
}
