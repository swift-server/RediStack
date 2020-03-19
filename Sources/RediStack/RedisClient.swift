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
    /// The `NIO.EventLoop` that this client operates on.
    var eventLoop: EventLoop { get }
    
    /// The `Logging.Logger` that this client uses.
    var logger: Logger { get }

    /// Sends the desired command with the specified arguments.
    /// - Parameters:
    ///     - command: The command to execute.
    ///     - arguments: The arguments, if any, to be sent with the command.
    /// - Returns: A `NIO.EventLoopFuture` that will resolve with the Redis command response.
    func send(command: String, with arguments: [RESPValue]) -> EventLoopFuture<RESPValue>
    
    /// Updates the client's logger.
    /// - Parameter logger: The `Logging.Logger` that is desired to receive all client logs.
    func setLogging(to logger: Logger)
}

extension RedisClient {
    /// Sends the desired command without arguments.
    /// - Parameter command: The command keyword to execute.
    /// - Returns: A `NIO.EventLoopFuture` that will resolve with the Redis command response.
    public func send(command: String) -> EventLoopFuture<RESPValue> {
        return self.send(command: command, with: [])
    }
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
