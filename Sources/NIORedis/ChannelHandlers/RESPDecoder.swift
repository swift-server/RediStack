import Foundation
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

private extension ByteBuffer {
    /// Copies bytes from the `ByteBuffer` from at the provided position, up to the length desired.
    ///
    ///     buffer.copyBytes(at: 3, length: 2)
    ///     // Optional(2 bytes), assuming buffer contains 5 bytes
    ///
    /// - Parameters:
    ///     - at: The position offset to copy bytes from the buffer, defaulting to `0`.
    ///     - length: The number of bytes to copy.
    func copyBytes(at offset: Int = 0, length: Int) -> [UInt8]? {
        guard readableBytes >= offset + length else { return nil }
        return getBytes(at: offset + readerIndex, length: length)
    }
}

/// Handles incoming byte messages from Redis and decodes them according to the RESP protocol.
///
/// See: https://redis.io/topics/protocol
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
    /// See https://redis.io/topics/protocol
    /// - Parameters:
    ///     - at: The index of the buffer that should be considered the "front" to begin message parsing.
    ///     - from: The buffer that contains the bytes that need to be decoded.
    public func parse(at position: inout Int, from buffer: inout ByteBuffer) throws -> ParsingState {
        guard let token = buffer.copyBytes(at: position, length: 1)?.first else { return .notYetParsed }

        position += 1

        switch token {
        case .plus:
            guard let string = try _parseSimpleString(at: &position, from: &buffer) else { return .notYetParsed }
            return .parsed(.simpleString(string))

        case .colon:
            guard let number = try _parseInteger(at: &position, from: &buffer) else { return .notYetParsed }
            return .parsed(.integer(number))

        case .dollar:
            return try _parseBulkString(at: &position, from: &buffer)

        case .asterisk:
            return try _parseArray(at: &position, from: &buffer)

        case .hyphen:
            guard let string = try _parseSimpleString(at: &position, from: &buffer) else { return .notYetParsed }
            return .parsed(.error(RedisError(identifier: "serverSide", reason: string)))

        default:
            throw RedisError(
                identifier: "invalidTokenType",
                reason: "Unexpected error while parsing Redis RESP."
            )
        }
    }

    /// See https://redis.io/topics/protocol#resp-simple-strings
    func _parseSimpleString(at position: inout Int, from buffer: inout ByteBuffer) throws -> String? {
        let byteCount = buffer.readableBytes - position
        guard
            byteCount >= 2, // strings should at least have a CRLF line ending
            let bytes = buffer.copyBytes(at: position, length: byteCount)
        else { return nil }

        // String endings have a return carriage followed by a newline
        // Search for the first \r and to find the expected newline offset
        var expectedNewlinePosition = 0
        for offset in 0..<bytes.count {
            if bytes[offset] == .carriageReturn {
                expectedNewlinePosition = offset + 1
                break
            }
        }

        // Make sure the position is still within readable range, and that the position reality matches our
        // expectation
        guard
            expectedNewlinePosition < bytes.count,
            bytes[expectedNewlinePosition] == .newline
        else { return nil }

        // Move the tip of the message position for recursive parsing to just after the newline
        position += expectedNewlinePosition + 1

        return String(bytes: bytes[ ..<(expectedNewlinePosition - 1) ], encoding: .utf8)
    }

    /// See https://redis.io/topics/protocol#resp-integers
    func _parseInteger(at position: inout Int, from buffer: inout ByteBuffer) throws -> Int? {
        guard let string = try _parseSimpleString(at: &position, from: &buffer) else { return nil }

        guard let number = Int(string) else {
            throw RedisError(
                identifier: "parseInteger",
                reason: "Unexpected error while parsing Redis RESP."
            )
        }

        return number
    }

    /// See https://redis.io/topics/protocol#resp-bulk-strings
    func _parseBulkString(at position: inout Int, from buffer: inout ByteBuffer) throws -> ParsingState {
        guard let size = try _parseInteger(at: &position, from: &buffer) else { return .notYetParsed }

        // Redis sends '-1' to represent a null string
        guard size > -1 else { return .parsed(.null) }

        // verify that we have our expected bulk string message
        // by adding the expected CRLF bytes to the parsed size
        // even if the size is 0, Redis provides line endings (i.e. $0\r\n\r\n)
        let readableByteCount = buffer.readableBytes - position
        let expectedRemainingMessageSize = size + 2
        guard readableByteCount >= expectedRemainingMessageSize else { return .notYetParsed }

        guard size > 0 else {
            // Move the tip of the message position
            position += 2
            return .parsed(.bulkString(Data()))
        }

        guard let bytes = buffer.copyBytes(at: position, length: expectedRemainingMessageSize) else {
            return .notYetParsed
        }

        // Move the tip of the message position for recursive parsing to just after the newline
        // of the bulk string content
        position += expectedRemainingMessageSize

        return .parsed(
            .bulkString(Data(bytes[ ..<size ]))
        )
    }

    /// See https://redis.io/topics/protocol#resp-arrays
    func _parseArray(at position: inout Int, from buffer: inout ByteBuffer) throws -> ParsingState {
        guard let arraySize = try _parseInteger(at: &position, from: &buffer) else { return .notYetParsed }
        guard arraySize > -1 else { return .parsed(.null) }
        guard arraySize > 0 else { return .parsed(.array([])) }

        var array = [ParsingState](repeating: .notYetParsed, count: arraySize)
        for index in 0..<arraySize {
            guard buffer.readableBytes - position > 0 else { return .notYetParsed }

            let parseResult = try parse(at: &position, from: &buffer)
            switch parseResult {
            case .parsed:
                array[index] = parseResult
            default:
                return .notYetParsed
            }
        }

        let values = try array.map { state -> RESPValue in
            guard case .parsed(let value) = state else {
                throw RedisError(
                    identifier: "parseArray",
                    reason: "Unexpected error while parsing Redis RESP."
                )
            }
            return value
        }
        return .parsed(.array(values))
    }
}

extension RESPDecoder: ByteToMessageDecoder {
    /// `ByteToMessageDecoder.InboundOut`
    public typealias InboundOut = RESPValue

    /// See `ByteToMessageDecoder.decode(ctx:buffer:)`
    public func decode(ctx: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        var position = 0

        switch try parse(at: &position, from: &buffer) {
        case .notYetParsed:
            return .needMoreData

        case .parsed(let RESPValue):
            ctx.fireChannelRead(wrapInboundOut(RESPValue))
            buffer.moveReaderIndex(forwardBy: position)
            return .continue
        }
    }
}
