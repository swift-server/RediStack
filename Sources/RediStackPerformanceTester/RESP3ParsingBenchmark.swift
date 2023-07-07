import NIOCore
import RESP3

func benchmarkRESP3Parsing() throws {
    let valueBuffer = ByteBuffer(string: "*2\r\n$3\r\nGET\r\n$7\r\nwelcome\r\n")
    let values: [RESP3Token.Value] = [
        .blobString(ByteBuffer(string: "GET")),
        .blobString(ByteBuffer(string: "welcome")),
    ]
    
    try benchmark {
        var valueBuffer = valueBuffer

        guard
            let token = try RESP3Token(consuming: &valueBuffer),
            case .array(let array) = token.value,
            array.map(\.value) == values
        else {
            fatalError("\(#function) Test failed: Invalid test result")
        }
    }
}
