@testable import RediStack
import XCTest

class RedisErrorTests: XCTestCase {
    func testLoggableDescriptionLocalized() {
        let error = RedisError(reason: "test")
        XCTAssertEqual(error.loggableDescription, "(Redis) test")
    }
    func testLoggableDescriptionNotLocalized() {
        struct MyError: Error, CustomStringConvertible {
            var field: String
            var description: String {
                "description of \(self.field)"
            }
        }
        let error = MyError(field: "test")
        XCTAssertEqual(error.loggableDescription, "description of test")
        // Trying to take a localizedDescription would give a less useful message like
        // "The operation couldn’t be completed. (RediStackTests.RedisErrorTests.(unknown context at $10aa9f334).(unknown context at $10aa9f340).MyError error 1.)"
        XCTAssertTrue(error.localizedDescription.starts(with: "The operation couldn’t be completed. (RediStackTests.RedisErrorTests.(unknown context at "))
    }
}
