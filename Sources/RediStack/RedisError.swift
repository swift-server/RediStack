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

import protocol Foundation.LocalizedError

/// If something goes wrong with a command within Redis, it will respond with an error that is captured and represented by instances of this type.
public struct RedisError: LocalizedError {
    /// The error message from Redis, prefixed with `(Redis)` to indicate the message was from Redis itself.
    public let message: String

    public var errorDescription: String? { return message }

    /// Creates a new instance of an error from a Redis instance.
    /// - Parameter reason: The error reason from Redis.
    public init(reason: String) {
        message = "(Redis) \(reason)"
    }
}

// MARK: Equatable, Hashable

extension RedisError: Equatable, Hashable {
    public static func ==(lhs: RedisError, rhs: RedisError) -> Bool {
        return lhs.message == rhs.message
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.message)
    }
}

// MARK: RESPValueConvertible

extension RedisError: RESPValueConvertible {
    /// Unwraps an `.error` representation directly into a `RedisError` instance.
    ///
    /// See `RESPValueConvertible.init(fromRESP:)`
    public init?(fromRESP value: RESPValue) {
        guard case let .error(e) = value else { return nil }
        self = e
    }

    public func convertedToRESPValue() -> RESPValue {
        return .error(self)
    }
}
