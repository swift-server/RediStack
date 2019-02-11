import NIO

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
