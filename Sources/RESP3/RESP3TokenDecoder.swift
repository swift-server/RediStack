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

public struct RESP3TokenDecoder: NIOSingleStepByteToMessageDecoder {
    public typealias InboundOut = RESP3Token

    public init() {}

    public mutating func decode(buffer: inout ByteBuffer) throws -> RESP3Token? {
        try RESP3Token(consuming: &buffer)
    }

    public mutating func decodeLast(buffer: inout ByteBuffer, seenEOF _: Bool) throws -> RESP3Token? {
        try self.decode(buffer: &buffer)
    }
}
