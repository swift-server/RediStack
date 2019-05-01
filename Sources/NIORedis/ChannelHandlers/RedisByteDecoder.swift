import NIO

/// Handles incoming byte messages from Redis
/// and decodes them according to the Redis Serialization Protocol (RESP).
///
/// See `NIO.ByteToMessageDecoder`, `RESPTranslator` and [https://redis.io/topics/protocol](https://redis.io/topics/protocol)
public final class RedisByteDecoder: ByteToMessageDecoder {
    /// `ByteToMessageDecoder.InboundOut`
    public typealias InboundOut = RESPValue

    /// See `ByteToMessageDecoder.decode(context:buffer:)`
    public func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        var position = 0

        switch try RESPTranslator.parseBytes(&buffer, fromIndex: &position) {
        case .incomplete: return .needMoreData
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
