import Logging
import NIO

/// Encodes `RedisValue` into a raw `ByteBuffer`, formatted according to the Redis Serialization Protocol (RESP).
///
/// See: [https://redis.io/topics/protocol](https://redis.io/topics/protocol)
public final class RESPEncoder {
    let logger: Logger

    public init(logger: Logger = Logger(label: "NIORedis.RESPEncoder")) {
        self.logger = logger
    }

    /// Encodes the `RedisValue` to bytes, following the RESP specification.
    ///
    /// See [https://redis.io/topics/protocol](https://redis.io/topics/protocol) and `RESPEncoder.encode(data:out:)`
    /// - Parameter value: The `RESPValue` to encode.
    /// - Returns: The encoded value as a collection of bytes.
    public func encode(data: RESPValue, out: inout ByteBuffer) {
        defer { logger.debug("Encoded \(data) to \(getPrintableString(for: &out))") }

        switch data {
        case .simpleString(var buffer):
            out.writeStaticString("+")
            out.writeBuffer(&buffer)
            out.writeStaticString("\r\n")

        case .bulkString(.some(var buffer)):
            out.writeStaticString("$")
            out.writeString(buffer.readableBytes.description)
            out.writeStaticString("\r\n")
            out.writeBuffer(&buffer)
            out.writeString("\r\n")

        case .bulkString(.none):
            out.writeStaticString("$0\r\n\r\n")

        case .integer(let number):
            out.writeStaticString(":")
            out.writeString(number.description)
            out.writeStaticString("\r\n")

        case .null:
            out.writeStaticString("$-1\r\n")

        case .error(let error):
            out.writeStaticString("-")
            out.writeString(error.description)
            out.writeStaticString("\r\n")

        case .array(let array):
            out.writeStaticString("*")
            out.writeString(array.count.description)
            out.writeStaticString("\r\n")
            array.forEach { self.encode(data: $0, out: &out) }
        }
    }

    // used only for debugging purposes where we build a formatted string for the encoded bytes
    private func getPrintableString(for buffer: inout ByteBuffer) -> String {
        return String(describing: buffer.getString(at: 0, length: buffer.readableBytes))
            .dropFirst(9)
            .dropLast()
            .description
    }
}

extension RESPEncoder: MessageToByteEncoder {
    /// See `MessageToByteEncoder.OutboundIn`
    public typealias OutboundIn = RESPValue
}
