/// Encodes `RedisValue` into a raw `ByteBuffer`, formatted according to the Redis Serialization Protocol (RESP).
///
/// See: [https://redis.io/topics/protocol](https://redis.io/topics/protocol)
public final class RESPEncoder {
    public init() { }

    /// Encodes the `RedisValue` to bytes, following the RESP specification.
    ///
    /// See https://redis.io/topics/protocol
    /// - Parameter value: The `RESPValue` to encode.
    /// - Returns: The encoded value as a collection of bytes.
    public func encode(_ value: RESPValue, into buffer: inout ByteBuffer) {
        switch value {
        case .simpleString(let string):
            buffer.writeStaticString("+")
            buffer.writeString(string)
            buffer.writeStaticString("\r\n")

        case .bulkString(let data):
            buffer.writeStaticString("$")
            buffer.writeString(data.count.description)
            buffer.writeStaticString("\r\n")
            buffer.writeBytes(data)
            buffer.writeString("\r\n")

        case .integer(let number):
            buffer.writeStaticString(":")
            buffer.writeString(number.description)
            buffer.writeStaticString("\r\n")

        case .null:
            buffer.writeStaticString("$-1\r\n")

        case .error(let error):
            buffer.writeStaticString("-")
            buffer.writeString(error.description)
            buffer.writeStaticString("\r\n")

        case .array(let array):
            buffer.writeStaticString("*")
            buffer.writeString(array.count.description)
            buffer.writeStaticString("\r\n")
            array.forEach { self.encode($0, into: &buffer) }
        }
    }
}
