//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2019 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct Logging.Logger
import NIO

/// An object capable of sending commands and receiving responses.
///
///     let client = ...
///     let result = client.send(command: "GET", arguments: ["my_key"])
///     // result == EventLoopFuture<RESPValue>
///
/// See [https://redis.io/commands](https://redis.io/commands)
public protocol RedisClient {
    /// Is the client currently connected to Redis?
    var isConnected: Bool { get }
    
    /// The `NIO.EventLoop` that this client operates on.
    var eventLoop: EventLoop { get }
    
    /// The `Logging.Logger` that this client uses.
    var logger: Logger { get }

    /// Sends the provided command to Redis.
    /// - Parameter command: The command to send.
    /// - Returns: A `NIO.EventLoopFuture` that resolves the Redis command response.
    func sendCommand<T: RESPValueConvertible>(_ command: NewRedisCommand<T>) -> EventLoopFuture<T>
    
    /// Updates the client's logger.
    /// - Parameter logger: The `Logging.Logger` that is desired to receive all client logs.
    func setLogging(to logger: Logger)
}

extension RedisClient {
    /// Updates the client's logger and returns a reference to itself for chaining method calls.
    /// - Parameter logger: The `Logging.Logger` that is desired to receive all client logs.
    /// - Returns: A reference to the client for chaining method calls.
    @inlinable
    public func logging(to logger: Logger) -> Self {
        self.setLogging(to: logger)
        return self
    }
}
