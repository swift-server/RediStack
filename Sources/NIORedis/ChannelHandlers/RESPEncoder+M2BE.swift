import NIO

extension RESPEncoder: MessageToByteEncoder {
    /// See `MessageToByteEncoder.OutboundIn`
    public typealias OutboundIn = RESPValue

    /// See `RESPEncoder.encode(data:out:)`
    public func encode(data: RESPValue, out: inout ByteBuffer) throws {
        encode(data, into: &out)
    }
}
