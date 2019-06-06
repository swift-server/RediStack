//===----------------------------------------------------------------------===//
//
// This source file is part of the RedisNIO open source project
//
// Copyright (c) 2019 RedisNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RedisNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import protocol Foundation.LocalizedError

/// When working with RedisNIO, several errors are thrown to indicate problems
/// with state, assertions, or otherwise.
public enum RedisNIOError: LocalizedError {
    case connectionClosed
    case responseConversion(to: Any.Type)
    case unsupportedOperation(method: StaticString, message: String)
    case assertionFailure(message: String)

    public var errorDescription: String? {
        let message: String
        switch self {
        case .connectionClosed: message = "Connection was closed while trying to send command."
        case let .responseConversion(type): message = "Failed to convert RESP to \(type)"
        case let .unsupportedOperation(method, helpText): message = "\(method) - \(helpText)"
        case let .assertionFailure(text): message = text
        }
        return "RedisNIO: \(message)"
    }
}

/// When sending commands to a Redis server, errors caught will be returned as an error message.
/// These messages are represented by `RedisError` instances.
public struct RedisError: LocalizedError {
    public let message: String

    public var errorDescription: String? { return message }

    public init(reason: String) {
        message = "Redis: \(reason)"
    }
}
