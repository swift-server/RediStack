@testable import NIORedis
import XCTest

final class NIORedisTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(NIORedis().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
