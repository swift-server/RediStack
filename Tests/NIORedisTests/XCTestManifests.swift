import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(RedisByteDecoderTests.allTests),
        testCase(RedisMessageEncoderTests.allTests),
        testCase(RESPTranslatorParsingTests.allTests),
        testCase(RESPTranslatorWritingTests.allTests),
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
