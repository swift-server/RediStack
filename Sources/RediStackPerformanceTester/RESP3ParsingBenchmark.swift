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
import RESP3

func benchmarkRESP3Parsing() throws {
    let valueBuffer = ByteBuffer(string: "*2\r\n$3\r\nGET\r\n$7\r\nwelcome\r\n")
    let values: [RESP3Token.Value] = [
        .blobString(ByteBuffer(string: "GET")),
        .blobString(ByteBuffer(string: "welcome")),
    ]
    let token = RESP3Token.Unchecked(buffer: valueBuffer)

    try benchmark {
        let token = token

        guard
            case .array(let array) = try token.getValue(),
            array.count == values.count
        else {
            fatalError("\(#function) Test failed: Invalid test result")
        }
    }
}
