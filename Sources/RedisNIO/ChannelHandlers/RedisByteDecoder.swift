//===----------------------------------------------------------------------===//
//
// This source file is part of the RedisNIO open source project
//
// Copyright (c) 2019 RedisNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RedisNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIO

/// Handles incoming byte messages from Redis
/// and decodes them according to the Redis Serialization Protocol (RESP).
///
/// See `NIO.ByteToMessageDecoder`, `RESPTranslator` and [https://redis.io/topics/protocol](https://redis.io/topics/protocol)
public final class RedisByteDecoder: ByteToMessageDecoder {
    /// `ByteToMessageDecoder.InboundOut`
    public typealias InboundOut = RESPValue
    
    private let parser: RESPTranslator
    
    public init() {
        self.parser = RESPTranslator()
    }

    /// See `ByteToMessageDecoder.decode(context:buffer:)`
    public func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        guard let value = try self.parser.parseBytes(from: &buffer) else { return .needMoreData }
        
        context.fireChannelRead(wrapInboundOut(value))
        return .continue
    }

    /// See `ByteToMessageDecoder.decodeLast(context:buffer:seenEOF)`
    public func decodeLast(
        context: ChannelHandlerContext,
        buffer: inout ByteBuffer,
        seenEOF: Bool
    ) throws -> DecodingState { return .needMoreData }
}
