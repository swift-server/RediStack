//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2019-2020 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import protocol Foundation.LocalizedError
import struct Logging.Logger
import NIOCore

/// An object capable of sending commands pipelines and receiving responses.
///
///     let client = ...
///     let result = client.send(commands: [("GET", ["my_key"])])
///     // result == EventLoopFuture<RESPValue>
///
/// For the full list of available commands, see [https://redis.io/commands](https://redis.io/commands)
public protocol RedisPipelineClient: RedisClient {
    func send<T: RedisCommandSignature>(_ command: T) -> EventLoopFuture<T.Value>
}

public protocol RedisCommandSignature<Value> {
    associatedtype Value
    var commands: [(command: String, arguments: [RESPValue])] { get }
    func makeResponse(from response: RESPValue) throws -> Value
}
