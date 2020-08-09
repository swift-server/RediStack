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
import NIO

// - Important: Any RedisClient defined by RediStack should conform to the RedisClientWithUserContext protocol as well

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

    /// Sends the desired command with the specified arguments.
    /// - Parameters:
    ///     - command: The command to execute.
    ///     - arguments: The arguments, if any, to be sent with the command.
    /// - Returns: A `NIO.EventLoopFuture` that will resolve with the Redis command response.
    func send(command: String, with arguments: [RESPValue]) -> EventLoopFuture<RESPValue>
    
    /// Temporarily overrides the default logger for command logs to the provided instance.
    /// - Parameter logger: The `Logging.Logger` instance to use for command logs.
    /// - Returns: A RedisClient with the temporary override for command logging.
    func logging(to logger: Logger) -> RedisClient
}

extension RedisClient {
    /// Sends the desired command without arguments.
    /// - Parameter command: The command keyword to execute.
    /// - Returns: A `NIO.EventLoopFuture` that will resolve with the Redis command response.
    public func send(command: String) -> EventLoopFuture<RESPValue> {
        return self.send(command: command, with: [])
    }
}

// MARK: Errors

/// When working with `RedisClient`, runtime errors can be thrown to indicate problems with connection state, decoding assertions, or otherwise.
public struct RedisClientError: LocalizedError, Equatable, Hashable {
    /// The connection is closed, but was used to try and send a command to Redis.
    public static let connectionClosed = RedisClientError(.connectionClosed)
    
    /// Conversion from `RESPValue` to the specified type failed.
    ///
    /// If this is ever triggered, please capture the original `RESPValue` string sent from Redis for bug reports.
    public static func failedRESPConversion(to type: Any.Type) -> RedisClientError {
        return .init(.failedRESPConversion(to: type))
    }
    
    /// Expectations of message structures were not met.
    ///
    /// If this is ever triggered, please capture the original `RESPValue` string sent from Redis along with the command and arguments sent to Redis for bug reports.
    public static func assertionFailure(message: String) -> RedisClientError {
        return .init(.assertionFailure(message: message))
    }
    
    public var errorDescription: String? {
        let message: String
        switch self.baseError {
        case .connectionClosed: message = "trying to send command with a closed connection"
        case let .failedRESPConversion(type): message = "failed to convert RESP to \(type)"
        case let .assertionFailure(text): message = text
        }
        return "(RediStack) \(message)"
    }
    
    public var recoverySuggestion: String? {
        switch self.baseError {
        case .connectionClosed: return "Check that the connection is not closed before invoking commands. With RedisConnection, this can be done with the 'isConnected' property."
        case .failedRESPConversion: return "Ensure that the data type being requested is actually what's being returned. If you see this error and are not sure why, capture the original RESPValue string sent from Redis to add to your bug report."
        case .assertionFailure: return "This error should in theory never happen. If you trigger this error, capture the original RESPValue string sent from Redis along with the command and arguments that you sent to Redis to add to your bug report."
        }
    }
    
    private var baseError: BaseError
    
    private init(_ baseError: BaseError) { self.baseError = baseError }
    
    /* Protocol Conformances and Private Type implementation */
    
    public static func ==(lhs: RedisClientError, rhs: RedisClientError) -> Bool {
        return lhs.localizedDescription == rhs.localizedDescription
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.localizedDescription)
    }
    
    fileprivate enum BaseError {
        case connectionClosed
        case failedRESPConversion(to: Any.Type)
        case assertionFailure(message: String)
    }
}
