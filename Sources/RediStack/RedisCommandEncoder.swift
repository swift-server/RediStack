//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2023 Apple Inc. and the RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOCore

protocol RESP3BlobStringEncodable {
    func encodeRedisBlobString(into buffer: inout ByteBuffer)
}

/// A Redis client sends commands to a Redis server using RESP. However clients are expected to only
/// sent [RESP Array of Bulk Strings](https://redis.io/docs/reference/protocol-spec/).
/// This allows us to make some heavy optimizations.
///
/// ``RedisCommandEncoder`` supports writing ``RESP3BlobStringEncodable`` into an outgoing buffer.
struct RedisCommandEncoder {
    var buffer: ByteBuffer

    #if swift(>=5.9)
    mutating func encodeRESPArray<each S: RESP3BlobStringEncodable>(
        _ first: some RESP3BlobStringEncodable,
        _ args: repeat each S
    ) {
        let count = ComputeParameterPackLength.count(ofPack: repeat each args)

        self.buffer.writeBytes("*".utf8)
        self.buffer.writeBytes("\(count + 1)".utf8)
        self.buffer.writeRESPNewLine()
        first.encodeRedisBlobString(into: &self.buffer)
        repeat ((each args).encodeRedisBlobString(into: &self.buffer))
    }
    #endif
}

extension String: RESP3BlobStringEncodable {
    func encodeRedisBlobString(into buffer: inout ByteBuffer) {
        buffer.writeBytes("$".utf8)
        buffer.writeBytes("\(self.utf8.count)".utf8)
        buffer.writeRESPNewLine()
        buffer.writeBytes(self.utf8)
        buffer.writeRESPNewLine()
    }
}

extension ByteBuffer: RESP3BlobStringEncodable {
    func encodeRedisBlobString(into buffer: inout ByteBuffer) {
        var mutable = self
        buffer.writeBytes("$".utf8)
        buffer.writeBytes("\(self.readableBytes)".utf8)
        buffer.writeRESPNewLine()
        buffer.writeBuffer(&mutable)
        buffer.writeRESPNewLine()
    }
}

#if swift(>=5.9)
private enum ComputeParameterPackLength {
    enum BoolConverter<T> {
        typealias Bool = Swift.Bool
    }

    static func count<each T>(ofPack t: repeat each T) -> Int {
        MemoryLayout<(repeat BoolConverter<each T>.Bool)>.size / MemoryLayout<Bool>.stride
    }
}
#endif

extension ByteBuffer {
    mutating func writeRESPNewLine() {
        self.writeBytes("\r\n".utf8)
    }
}
