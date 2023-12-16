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
import RediStack

func runRESPArrayParsing(
    valueBuffer: ByteBuffer,
    valueCount: Int
) throws {
    let translator = RESPTranslator()
    var valueBuffer = valueBuffer
    let value = try translator.parseBytes(from: &valueBuffer)
    guard case .array(let result) = value, result.count == valueCount else {
        fatalError("\(#function) Test failed: Invalid test result")
    }
}
