import NIO

extension RESPEncoder: MessageToByteEncoder {
    /// See `MessageToByteEncoder.OutboundIn`
    public typealias OutboundIn = RESPValue

    /// See `RESPEncoder.encode(context:data:out:)`
    public func encode(context: ChannelHandlerContext, data: RESPValue, out: inout ByteBuffer) throws {
        out.writeBytes(encode(data))
    }
}
