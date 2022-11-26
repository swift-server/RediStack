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

import NIO

/// Handles incoming byte messages from Redis
/// and decodes them according to the Redis Serialization Protocol (RESP).
///
/// See `NIO.NIOSingleStepByteToMessageDecoder`, `RESPTranslator` and [https://redis.io/topics/protocol](https://redis.io/topics/protocol)
public struct RedisByteDecoder: NIOSingleStepByteToMessageDecoder {
    /// `ByteToMessageDecoder.InboundOut`
    public typealias InboundOut = RESPValue
    
    private let parser: RESPTranslator
    
    public init() {
        self.parser = RESPTranslator()
    }

    /// See `NIOSingleStepByteToMessageDecoder.decode(buffer:)`
    public func decode(buffer: inout ByteBuffer) throws -> RESPValue? {
        try self.parser.parseBytes(from: &buffer)
    }

    /// See `NIOSingleStepByteToMessageDecoder.decodeLast(buffer:seenEOF)`
    public func decodeLast(buffer: inout ByteBuffer, seenEOF: Bool) throws -> RESPValue? {
        try self.decode(buffer: &buffer)
    }
}
