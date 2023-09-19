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

/// A description of a single node that is part of a redis cluster
public protocol RedisClusterNodeDescriptionProtocol: Sendable, Equatable {
    /// The node's host name.
    var host: String? { get }
    /// The node's ip address.
    var ip: String? { get }
    /// The nodes endpoint. This should normally be the ``host`` if the node has a routable hostname.
    /// Otherwise it is the ``ip``. This property is used to create connections to the node.
    var endpoint: String { get }
    /// The node's redis port
    var port: Int { get }
    /// Defines if TLS shall be used to create a connection to the node
    var useTLS: Bool { get }

    /// A resolved SocketAddress to the node. We will remove this property as soon as we have fixed
    /// the underlying Redis implementation.
    var socketAddress: SocketAddress { get }
}

extension RedisClusterNodeDescriptionProtocol {
    func isSame<Other: RedisClusterNodeDescriptionProtocol>(_ other: Other) -> Bool {
        return self.ip == other.ip
            && self.port == other.port
            && self.endpoint == other.endpoint
            && self.useTLS == other.useTLS
            && self.host == other.host
    }
}

extension RedisClusterNodeDescriptionProtocol {
    @inlinable
    public var id: RedisClusterNodeID {
        RedisClusterNodeID(endpoint: self.endpoint, port: self.port)
    }
}
