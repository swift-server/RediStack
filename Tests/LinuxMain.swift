import XCTest

import RediStackIntegrationTests
import RediStackTests

var tests = [XCTestCaseEntry]()
tests += RediStackIntegrationTests.__allTests()
tests += RediStackTests.__allTests()

XCTMain(tests)
