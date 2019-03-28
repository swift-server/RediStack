import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(RESPDecoderTests.allTests),
        testCase(RESPDecoderParsingTests.allTests),
        testCase(RESPDecoderByteToMessageDecoderTests.allTests),
        testCase(RESPEncoderTests.allTests),
        testCase(RESPEncoderParsingTests.allTests),
        testCase(BasicCommandsTests.allTests),
        testCase(SetCommandsTests.allTests),
        testCase(RedisPipelineTests.allTests),
        testCase(HashCommandsTests.allTests),
        testCase(ListCommandsTests.allTests),
        testCase(SortedSetCommandsTests.allTests),
        testCase(StringCommandsTests.allTests)
    ]
}
#endif
