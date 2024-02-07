//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2023 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOCore
@_spi(RESP3) import RediStack

func runRESP3ArrayParsing(
    valueBuffer: ByteBuffer,
    valueCount: Int
) throws {
    let token = RESP3Token.Unchecked(buffer: valueBuffer)

    guard
        case .array(let array) = try token.getValue(),
        array.count == valueCount
    else {
        fatalError("\(#function) Test failed: Invalid test result")
    }
}
