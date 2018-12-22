import Foundation
import NIO

/// Handles outgoing `RedisData` on the wire by encoding it to the Redis RESP protocol.
///
/// See: https://redis.io/topics/protocol
final class RedisDataEncoder: MessageToByteEncoder {
    /// See `MessageToByteEncoder.OutboundIn`
    typealias OutboundIn = RedisData

    /// See `RedisDataEncoder.encode(ctx:data:out:)`
    func encode(ctx: ChannelHandlerContext, data: RedisData, out: inout ByteBuffer) throws {
        out.write(bytes: _encode(data: data))
    }

    func _encode(data: RedisData) -> Data {
        switch data {
        case .simpleString(let string):
            return "+\(string)\r\n".convertedToData()

        case .bulkString(let data):
            return "$\(data.count)\r\n".convertedToData() + data + "\r\n".convertedToData()

        case .integer(let number):
            return ":\(number)\r\n".convertedToData()

        case .null:
            return "$-1\r\n".convertedToData()

        case .error(let error):
            return "-\(error.description)\r\n".convertedToData()

        case .array(let array):
            let encodedArray = array.map { _encode(data: $0) }.joined()
            return "*\(array.count)\r\n".convertedToData() + encodedArray
        }
    }
}
