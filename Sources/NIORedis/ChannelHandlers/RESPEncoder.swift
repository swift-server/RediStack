import Foundation
import NIO

/// Translates `RedisValue` into raw bytes, formatted according to the Redis Serialization Protocol (RESP).
///
/// See: https://redis.io/topics/protocol
public final class RESPEncoder {
    /// Encodes the `RedisValue` to bytes, following the RESP specification.
    ///
    /// See https://redis.io/topics/protocol
    /// - Parameter value: The `RESPValue` to encode.
    /// - Returns: The encoded value as a collection of bytes.
    public func encode(_ value: RESPValue) -> Data {
        switch value {
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
            let encodedArray = array.map(encode).joined()
            return "*\(array.count)\r\n".convertedToData() + encodedArray
        }
    }
}

// MARK: MessageToByteEncoder

extension RESPEncoder: MessageToByteEncoder {
    /// See `MessageToByteEncoder.OutboundIn`
    public typealias OutboundIn = RESPValue

    /// See `RESPEncoder.encode(ctx:data:out:)`
    public func encode(ctx: ChannelHandlerContext, data: RESPValue, out: inout ByteBuffer) throws {
        out.write(bytes: encode(data))
    }
}
