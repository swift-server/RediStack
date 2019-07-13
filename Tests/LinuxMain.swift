import XCTest

import RediStackTests

var tests = [XCTestCaseEntry]()
tests += RediStackTests.__allTests()

XCTMain(tests)
