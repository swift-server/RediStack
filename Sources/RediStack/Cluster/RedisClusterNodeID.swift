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

/// Properties to identifiy a Node in a Redis cluster
public struct RedisClusterNodeID: Hashable, Sendable {
    /// The node's endpoint. This might be the hostname (preferred) or ip address
    public var endpoint: String
    /// The node's redis port
    public var port: Int

    public init(endpoint: String, port: Int) {
        self.endpoint = endpoint
        self.port = port
    }
}
