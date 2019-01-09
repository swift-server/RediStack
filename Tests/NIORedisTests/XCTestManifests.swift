import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(NIORedisTests.allTests),
        testCase(RESPDecoderTests.allTests),
        testCase(RESPDecoderParsingTests.allTests),
        testCase(RESPDecoderByteToMessageDecoderTests.allTests),
        testCase(RESPEncoderTests.allTests),
        testCase(RESPEncoderParsingTests.allTests),
        testCase(BasicCommandsTests.allTests),
        testCase(NIORedisPipelineTests.allTests)
    ]
}
#endif
