import NIO

extension RESPEncoder: MessageToByteEncoder {
    /// See `MessageToByteEncoder.OutboundIn`
    public typealias OutboundIn = RESPValue

    /// See `RESPEncoder.encode(data:out:)`
    public func encode(data: RESPValue, out: inout ByteBuffer) throws {
        encode(data, into: &out)

        logger.debug("Encoded \(data) to \(getPrintableString(for: &out))")
    }

    // used only for debugging purposes where we build a formatted string for the encoded bytes
    private func getPrintableString(for buffer: inout ByteBuffer) -> String {
        return String(describing: buffer.getString(at: 0, length: buffer.readableBytes))
            .dropFirst(9)
            .dropLast()
            .description
    }
}
