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

@_spi(RESP3) import RediStack
import Benchmark
import NIOCore

let benchmarks = {
    let resp3ArrayValueBuffer = ByteBuffer(string: "*2\r\n$3\r\nGET\r\n$7\r\nwelcome\r\n")
    let resp3ArrayCount = 2

    Benchmark("RESP3 Array Parsing") { benchmark in
        try runRESP3ArrayParsing(
            valueBuffer: resp3ArrayValueBuffer,
            valueCount: resp3ArrayCount
        )
    }

    let respArrayValueBuffer = ByteBuffer(string: "*2\r\n$3\r\nGET\r\n$7\r\nwelcome\r\n")
    let respArrayCount = 2
    Benchmark("RESP Array Parsing") { benchmark in
        try runRESPArrayParsing(
            valueBuffer: respArrayValueBuffer,
            valueCount: respArrayCount
        )
    }

    Benchmark("RESP3 Conversation") { benchmark in
        try runRESP3Protocol()
    }

    Benchmark("RESP Conversation") { benchmark in
        try runRESPProtocol()
    }
}
