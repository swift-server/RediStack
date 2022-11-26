//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2019-2022 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOCore

#if DEBUG
// used only for debugging purposes where we build a formatted string for the encoded bytes
private func getPrintableString(for buffer: inout ByteBuffer) -> String {
    return String(describing: buffer.getString(at: 0, length: buffer.readableBytes))
        .dropFirst(9)
        .dropLast()
        .description
}
#endif

/// Encodes outgoing `RESPValue` data into a raw `ByteBuffer` according to the Redis Serialization Protocol (RESP).
///
/// See `NIO.MessageToByteEncoder`, `RESPTranslator`, and [https://redis.io/topics/protocol](https://redis.io/topics/protocol)
public final class RedisMessageEncoder: MessageToByteEncoder {
    /// See `MessageToByteEncoder.OutboundIn`
    public typealias OutboundIn = RESPValue

    public init() { }

    /// Encodes the `RedisValue` to bytes, following the RESP specification.
    ///
    /// See [https://redis.io/topics/protocol](https://redis.io/topics/protocol) and `RESPEncoder.encode(data:out:)`
    public func encode(data: RESPValue, out: inout ByteBuffer) throws {
        out.writeRESPValue(data)
        // if you're looking to debug the value, set a breakpoint on the return and use `getPrintableString(for:)`
        // e.g. `po getPrintableString(for: &out)`
        return
    }
}
