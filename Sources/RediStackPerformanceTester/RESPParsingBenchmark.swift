import NIOCore
import RediStack

func benchmarkRESPParsing() throws {
    let valueBuffer = ByteBuffer(string: "*2\r\n$3\r\nGET\r\n$7\r\nwelcome\r\n")
    let result: [RESPValue] = [
        .bulkString(ByteBuffer(string: "GET")),
        .bulkString(ByteBuffer(string: "welcome")),
    ]
    let translator = RESPTranslator()
    try benchmark {
        var valueBuffer = valueBuffer
        let value = try translator.parseBytes(from: &valueBuffer)
        guard case .array(result) = value else {
            fatalError("\(#function) Test failed: Invalid test result")
        }
    }
}
