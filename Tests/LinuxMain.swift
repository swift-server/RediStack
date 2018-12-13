import XCTest

import NIORedisTests

var tests = [XCTestCaseEntry]()
tests += NIORedisTests.allTests()
XCTMain(tests)
