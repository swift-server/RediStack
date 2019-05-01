import protocol Foundation.LocalizedError
import NIO

extension UInt8 {
    static let newline: UInt8 = 0xA
    static let carriageReturn: UInt8 = 0xD
    static let dollar: UInt8 = 0x24
    static let asterisk: UInt8 = 0x2A
    static let plus: UInt8 = 0x2B
    static let hyphen: UInt8 = 0x2D
    static let colon: UInt8 = 0x3A
}

/// Provides methods for translating between byte streams and Swift types
/// according to Redis Serialization Protocol (RESP).
///
/// See [https://redis.io/topics/protocol](https://redis.io/topics/protocol)
public enum RESPTranslator { }

// MARK: From Bytes

extension RESPTranslator {
    /// Representation of the result of a parse attempt on a byte stream.
    /// - incomplete: The stream contains an incomplete RESP message from the position provided.
    /// - parsed: The parsed `RESPValue`
    public enum ParsingResult {
        case incomplete
        case parsed(RESPValue)
    }

    /// Representation of a `Swift.Error` found during RESP parsing.
    public enum ParsingError: LocalizedError {
        case invalidToken
        case arrayRecursion

        public var errorDescription: String? {
            return "RESPTranslator: \(self)"
        }
    }

    /// Attempts to parse the `ByteBuffer`, starting at the specified position,
    /// following the RESP specification.
    /// - Important: As this par
    ///
    /// See [https://redis.io/topics/protocol](https://redis.io/topics/protocol)
    /// - Parameters:
    ///     - buffer: The buffer that contains the bytes that need to be parsed.
    ///     - position: The index of the buffer that should contain the first byte of the message.
    public static func parseBytes(
        _ buffer: inout ByteBuffer,
        fromIndex position: inout Int
    ) throws -> ParsingResult {
        let offset = position + buffer.readerIndex
        guard
            let token = buffer.viewBytes(at: offset, length: 1)?.first,
            var slice = buffer.getSlice(at: offset, length: buffer.readableBytes - position)
        else { return .incomplete }

        position += 1

        switch token {
        case .plus:
            guard let result = parseSimpleString(&slice, &position) else { return .incomplete }
            return .parsed(.simpleString(result))

        case .colon:
            guard let value = parseInteger(&slice, &position) else { return .incomplete }
            return .parsed(.integer(value))

        case .dollar:
            return parseBulkString(&slice, &position)

        case .asterisk:
            return try parseArray(&slice, &position)

        case .hyphen:
            guard
                let stringBuffer = parseSimpleString(&slice, &position),
                let message = stringBuffer.getString(at: 0, length: stringBuffer.readableBytes)
            else { return .incomplete }
            return .parsed(.error(RedisError(reason: message)))

        default: throw ParsingError.invalidToken
        }
    }

    /// See [https://redis.io/topics/protocol#resp-simple-strings](https://redis.io/topics/protocol#resp-simple-strings)
    static func parseSimpleString(_ buffer: inout ByteBuffer, _ position: inout Int) -> ByteBuffer? {
        guard
            let bytes = buffer.viewBytes(at: position, length: buffer.readableBytes - position),
            let newlineIndex = bytes.firstIndex(of: .newline),
            newlineIndex >= (position - bytes.startIndex) + 2 // strings should at least have a CRLF line ending
        else { return nil }

        // move the parsing position to the newline for recursive parsing
        position += newlineIndex

        // the end of the message will be just before the newlineIndex,
        // offset by the view's startIndex
        return buffer.getSlice(at: bytes.startIndex, length: (newlineIndex - 1) - bytes.startIndex)
    }

    /// See [https://redis.io/topics/protocol#resp-integers](https://redis.io/topics/protocol#resp-integers)
    static func parseInteger(_ buffer: inout ByteBuffer, _ position: inout Int) -> Int? {
        guard let stringBuffer = parseSimpleString(&buffer, &position) else { return nil }
        return stringBuffer.withUnsafeReadableBytes { ptr in
            Int(strtoll(ptr.bindMemory(to: Int8.self).baseAddress!, nil, 10))
        }
    }

    /// See [https://redis.io/topics/protocol#resp-bulk-strings](https://redis.io/topics/protocol#resp-bulk-strings)
    static func parseBulkString(_ buffer: inout ByteBuffer, _ position: inout Int) -> ParsingResult {
        guard let size = parseInteger(&buffer, &position) else { return .incomplete }

        // Redis sends '$-1\r\n' to represent a null bulk string
        guard size > -1 else { return .parsed(.null) }

        // verify that we have the entire bulk string message by adding the expected CRLF bytes
        // to the parsed size of the message content
        // even if the content is empty, Redis send '$0\r\n\r\n'
        let readableByteCount = buffer.readableBytes - position
        let expectedRemainingMessageSize = size + 2
        guard readableByteCount >= expectedRemainingMessageSize else { return .incomplete }

        // empty bulk strings, different from null strings, are represented as .bulkString(nil)
        guard size > 0 else {
            // move the parsing position to the newline for recursive parsing
            position += 2
            return .parsed(.bulkString(nil))
        }

        guard let bytes = buffer.viewBytes(at: position, length: expectedRemainingMessageSize) else {
            return .incomplete
        }

        // move the parsing position to the newline for recursive parsing
        position += expectedRemainingMessageSize

        return .parsed(.bulkString(
            buffer.getSlice(at: bytes.startIndex, length: size)
        ))
    }

    /// See [https://redis.io/topics/protocol#resp-arrays](https://redis.io/topics/protocol#resp-arrays)
    static func parseArray(_ buffer: inout ByteBuffer, _ position: inout Int) throws -> ParsingResult {
        guard let elementCount = parseInteger(&buffer, &position) else { return .incomplete }
        guard elementCount > -1 else { return .parsed(.null) } // '*-1\r\n'
        guard elementCount > 0 else { return .parsed(.array([])) } // '*0\r\n'

        var results = [ParsingResult](repeating: .incomplete, count: elementCount)
        for index in 0..<elementCount {
            guard
                var slice = buffer.getSlice(at: position, length: buffer.readableBytes - position)
            else { return .incomplete }

            var subPosition = 0
            let result = try parseBytes(&slice, fromIndex: &subPosition)
            switch result {
            case .parsed: results[index] = result
            default: return .incomplete
            }

            position += subPosition
        }

        let values = try results.map { state -> RESPValue in
            guard case let .parsed(value) = state else { throw ParsingError.arrayRecursion }
            return value
        }
        return .parsed(.array(ContiguousArray<RESPValue>(values)))
    }
}

// MARK: To Bytes

extension RESPTranslator {
    /// Writes the `RESPValue` into the provided `ByteBuffer` following the RESP specification.
    ///
    /// See [https://redis.io/topics/protocol](https://redis.io/topics/protocol)
    /// - Parameters:
    ///     - value: The value to write to the buffer.
    ///     - out: The buffer being written to.
    public static func writeValue(_ value: RESPValue, into out: inout ByteBuffer) {
        switch value {
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
            out.writeString(error.message)
            out.writeStaticString("\r\n")

        case .array(let array):
            out.writeStaticString("*")
            out.writeString(array.count.description)
            out.writeStaticString("\r\n")
            array.forEach { writeValue($0, into: &out) }
        }
    }
}
