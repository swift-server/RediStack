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
/// ```swift
/// let client = ...
/// let result = client.send(SETEX(key, to: value, expirationInSeconds: 3600)) // SETEX is an example command, not implemented in RediStack
/// // result == EventLoopFuture<Int>
/// ```
/// For the full list of available commands, see [https://redis.io/commands](https://redis.io/commands)
public protocol RedisPipelineClient: RedisClient {
    func send<T: RedisCommandSignature>(_ command: T) -> EventLoopFuture<T.Value>
}

/// A protocol that represents a Redis command.
///
/// ```swift
/// public struct SETEX: RedisCommandSignature, Equatable {
///
///     public typealias Value = Void
///
///     public var commands: [(command: String, arguments: [RESPValue])] {
///         [(
///             "SETEX",
///             [
///                 RESPValue(from: key),
///                 RESPValue(from: max(1, expirationInSeconds)),
///                 value
///             ]
///         )]
///     }
///
///     public var key: RedisKey
///     public var value: RESPValue
///     public var expirationInSeconds: Int
///
///     public init<T: RESPValueConvertible>(_ key: RedisKey, to value: T, expirationInSeconds: Int) {
///         self.key = key
///         self.value = value.convertedToRESPValue()
///         self.expirationInSeconds = expirationInSeconds
///     }
/// }
/// ```
public protocol RedisCommandSignature<Value> {
    associatedtype Value
    var commands: [(command: String, arguments: [RESPValue])] { get }
    func makeResponse(from response: RESPValue) throws -> Value
}

extension RedisPipelineClient {

    /// An object capable of sending commands pipelines and receiving responses.
    ///
    /// ```swift
    /// let client = ...
    /// let result = try await client.send(SETEX(key, to: value, expirationInSeconds: 3600)) // SETEX is an example command, not implemented in RediStack
    /// ```
    /// For the full list of available commands, see [https://redis.io/commands](https://redis.io/commands)
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public func send<T: RedisCommandSignature>(_ command: T) async throws -> T.Value {
        try await send(command).get()
    }
}

extension RedisCommandSignature where Value == Void {

    public func makeResponse(from response: RESPValue) throws -> Void {}
}

extension RedisCommandSignature where Value == RESPValue {

    public func makeResponse(from response: RESPValue) throws -> RESPValue { response }
}

extension RedisCommandSignature where Value: RESPValueConvertible {

    public func makeResponse(from response: RESPValue) throws -> Value {
        guard let value = Value(fromRESP: response) else {
            throw InvalidRESPValue()
        }
        return value
    }
}

private struct InvalidRESPValue: Error {}
