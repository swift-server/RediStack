import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(NIORedisTests.allTests),
        testCase(RedisDataDecoderTests.allTests),
        testCase(RedisDataDecoderParsingTests.allTests),
        testCase(RedisDataDecoderByteToMessageDecoderTests.allTests),
    ]
}
#endif
