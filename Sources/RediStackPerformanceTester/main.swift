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

import RediStack
import Foundation
import NIOCore
import NIOEmbedded
import RESP3

func benchmark(label: String = #function, _ n: Int = 100_000, run: () throws -> Void) throws {
    let start = Date()
    for _ in 0..<n {
        try run()
    }
    let end = Date()
    let mode: String

#if DEBUG
    mode = "DEBUG"
#else
    mode = "RELEASE"
#endif

    print("\(label): Test took \(end.timeIntervalSince(start)) seconds on \(mode)")
}

try benchmarkRESPProtocol()
try benchmarkRESP3Protocol()

try benchmarkRESPParsing()
try benchmarkRESP3Parsing()
