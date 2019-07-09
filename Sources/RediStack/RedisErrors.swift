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

/// When working with `RedisClient`, runtime errors can be thrown to indicate problems with connection state, decoding assertions, or otherwise.
public enum RedisClientError: LocalizedError {
    /// The connection is closed, but was used to try and send a command to Redis.
    case connectionClosed
    /// Conversion from `RESPValue` to the specified type failed.
    /// If this is ever triggered, please capture the original `RESPValue` value.
    case failedRESPConversion(to: Any.Type)
    /// Expectations of message structures were not met.
    /// If this is ever triggered, please capture the original byte message from Redis along with the command and arguments to Redis.
    case assertionFailure(message: String)

    public var errorDescription: String? {
        let message: String
        switch self {
        case .connectionClosed: message = "Connection was closed while trying to send command."
        case let .failedRESPConversion(type): message = "Failed to convert RESP to \(type)"
        case let .assertionFailure(text): message = text
        }
        return "RediStack: \(message)"
    }
}

/// If something goes wrong with a command within Redis, it will respond with an error that is captured and represented by instances of this type.
public struct RedisError: LocalizedError {
    public let message: String

    public var errorDescription: String? { return message }

    public init(reason: String) {
        message = "Redis: \(reason)"
    }
}
