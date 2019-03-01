import NIO

extension RESPDecoder: ByteToMessageDecoder {
    /// `ByteToMessageDecoder.InboundOut`
    public typealias InboundOut = RESPValue

    /// See `ByteToMessageDecoder.decode(context:buffer:)`
    public func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        var position = 0

        switch try parse(at: &position, from: &buffer) {
        case .notYetParsed:
            return .needMoreData

        case .parsed(let RESPValue):
            context.fireChannelRead(wrapInboundOut(RESPValue))
            buffer.moveReaderIndex(forwardBy: position)
            return .continue
        }
    }
    
    /// See `ByteToMessageDecoder.decodeLast(context:buffer:seenEOF)`
    public func decodeLast(context: ChannelHandlerContext, buffer: inout ByteBuffer, seenEOF: Bool) throws -> DecodingState {
        return .needMoreData
    }
}
