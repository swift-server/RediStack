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
import NIOCore

struct MockNodeDescription: RedisClusterNodeDescriptionProtocol, Hashable {
    var host: String?
    var endpoint: String
    var ip: String?
    var port: Int = 5432
    var useTLS: Bool

    var socketAddress: SocketAddress { try! .makeAddressResolvingHost(self.endpoint, port: self.port) }

    init(host: String? = "localhost", ip: String, endpoint: String? = nil, port: Int = 6379, useTLS: Bool) {
        self.host = host
        self.ip = ip
        self.endpoint = endpoint ?? host ?? ip
        self.port = port
        self.useTLS = useTLS
    }
}
