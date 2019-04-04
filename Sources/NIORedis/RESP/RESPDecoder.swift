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

/// Handles incoming byte messages from Redis and decodes them according to the RESP protocol.
///
/// See: [https://redis.io/topics/protocol](https://redis.io/topics/protocol)
public final class RESPDecoder {
    /// Representation of a `RESPDecoder.parse(at:from:) result, with either a decoded `RESPValue` or an indicator
    /// that the buffer contains an incomplete RESP message from the position provided.
    public enum ParsingState {
        case notYetParsed
        case parsed(RESPValue)
    }

    public init() { }

    /// Attempts to parse the `ByteBuffer`, starting at the specified position, following the RESP specification.
    ///
    /// See [https://redis.io/topics/protocol](https://redis.io/topics/protocol)
    /// - Parameters:
    ///     - buffer: The buffer that contains the bytes that need to be decoded.
    ///     - position: The index of the buffer that should be considered the "front" to begin message parsing.
    public func parse(from buffer: inout ByteBuffer, index position: inout Int) throws -> ParsingState {
        let offset = position + buffer.readerIndex
        guard
            let token = buffer.viewBytes(at: offset, length: 1)?.first,
            var slice = buffer.getSlice(at: offset, length: buffer.readableBytes - position)
        else { return .notYetParsed }

        position += 1

        switch token {
        case .plus:
            guard let result = parseSimpleString(&slice, &position) else { return .notYetParsed }
            return .parsed(.simpleString(result))

        case .colon:
            guard let value = parseInteger(&slice, &position) else { return .notYetParsed }
            return .parsed(.integer(value))

        case .dollar:
            return parseBulkString(&slice, &position)

        case .asterisk:
            return try parseArray(&slice, &position)

        case .hyphen:
            guard
                let stringBuffer = parseSimpleString(&slice, &position),
                let message = stringBuffer.getString(at: 0, length: stringBuffer.readableBytes)
            else { return .notYetParsed }
            return .parsed(.error(RedisError(identifier: "serverSide", reason: message)))

        default: throw RedisError(identifier: "invalidTokenType", reason: "Unexpected error while parsing Redis RESP.")
        }
    }
}

extension RESPDecoder: ByteToMessageDecoder {
    /// `ByteToMessageDecoder.InboundOut`
    public typealias InboundOut = RESPValue

    /// See `ByteToMessageDecoder.decode(context:buffer:)`
    public func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        var position = 0

        switch try parse(from: &buffer, index: &position) {
        case .notYetParsed: return .needMoreData
        case let .parsed(value):
            context.fireChannelRead(wrapInboundOut(value))
            buffer.moveReaderIndex(forwardBy: position)
            return .continue
        }
    }

    /// See `ByteToMessageDecoder.decodeLast(context:buffer:seenEOF)`
    public func decodeLast(
        context: ChannelHandlerContext,
        buffer: inout ByteBuffer,
        seenEOF: Bool
    ) throws -> DecodingState { return .needMoreData }
}

// MARK: Parsing

extension RESPDecoder {
    /// See [https://redis.io/topics/protocol#resp-simple-strings](https://redis.io/topics/protocol#resp-simple-strings)
    func parseSimpleString(_ buffer: inout ByteBuffer, _ position: inout Int) -> ByteBuffer? {
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
    func parseInteger(_ buffer: inout ByteBuffer, _ position: inout Int) -> Int? {
        guard let stringBuffer = parseSimpleString(&buffer, &position) else { return nil }
        return stringBuffer.withUnsafeReadableBytes { ptr in
            Int(strtoll(ptr.bindMemory(to: Int8.self).baseAddress!, nil, 10))
        }
    }

    /// See [https://redis.io/topics/protocol#resp-bulk-strings](https://redis.io/topics/protocol#resp-bulk-strings)
    func parseBulkString(_ buffer: inout ByteBuffer, _ position: inout Int) -> ParsingState {
        guard let size = parseInteger(&buffer, &position) else { return .notYetParsed }

        // Redis sends '$-1\r\n' to represent a null bulk string
        guard size > -1 else { return .parsed(.null) }

        // verify that we have the entire bulk string message by adding the expected CRLF bytes
        // to the parsed size of the message content
        // even if the content is empty, Redis send '$0\r\n\r\n'
        let readableByteCount = buffer.readableBytes - position
        let expectedRemainingMessageSize = size + 2
        guard readableByteCount >= expectedRemainingMessageSize else { return .notYetParsed }

        // empty bulk strings, different from null strings, are represented as .bulkString(nil)
        guard size > 0 else {
            // move the parsing position to the newline for recursive parsing
            position += 2
            return .parsed(.bulkString(nil))
        }

        guard let bytes = buffer.viewBytes(at: position, length: expectedRemainingMessageSize) else {
            return .notYetParsed
        }

        // move the parsing position to the newline for recursive parsing
        position += expectedRemainingMessageSize

        return .parsed(.bulkString(
            buffer.getSlice(at: bytes.startIndex, length: size)
        ))
    }

    /// See [https://redis.io/topics/protocol#resp-arrays](https://redis.io/topics/protocol#resp-arrays)
    func parseArray(_ buffer: inout ByteBuffer, _ position: inout Int) throws -> ParsingState {
        guard let elementCount = parseInteger(&buffer, &position) else { return .notYetParsed }
        guard elementCount > -1 else { return .parsed(.null) } // '*-1\r\n'
        guard elementCount > 0 else { return .parsed(.array([])) } // '*0\r\n'

        var results = [ParsingState](repeating: .notYetParsed, count: elementCount)
        for index in 0..<elementCount {
            guard
                var slice = buffer.getSlice(at: position, length: buffer.readableBytes - position)
            else { return .notYetParsed }

            var subPosition = 0
            let result = try parse(from: &slice, index: &subPosition)
            switch result {
            case .parsed: results[index] = result
            default: return .notYetParsed
            }

            position += subPosition
        }

        let values = try results.map { state -> RESPValue in
            guard case let .parsed(value) = state else {
                throw RedisError(identifier: "parseArray", reason: "Unexpected error while parsing RESP.")
            }
            return value
        }
        return .parsed(.array(ContiguousArray<RESPValue>(values)))
    }
}
