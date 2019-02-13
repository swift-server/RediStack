import NIO

extension RESPEncoder: MessageToByteEncoder {
    /// See `MessageToByteEncoder.OutboundIn`
    public typealias OutboundIn = RESPValue

    /// See `RESPEncoder.encode(ctx:data:out:)`
    public func encode(ctx: ChannelHandlerContext, data: RESPValue, out: inout ByteBuffer) throws {
        out.writeBytes(encode(data))
    }
}
