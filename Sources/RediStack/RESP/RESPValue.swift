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

import struct Foundation.Data
import NIO

/// A representation of a Redis Serialization Protocol (RESP) primitive value.
///
/// This enum representation should be used only as a temporary intermediate representation of values, and should be sent to a Redis server or converted to Swift
/// types as soon as possible.
///
/// Redis servers expect a single message packed into an `.array`, with all elements being `.bulkString` representations of values. As such, all initializers
/// convert to `.bulkString` representations, as well as default conformances for `RESPValueConvertible`.
///
/// Each case of this type is a different listing in the RESP specification, and several computed properties are available to consistently convert values into Swift types.
///
/// See: [https://redis.io/topics/protocol](https://redis.io/topics/protocol)
public enum RESPValue {
    case null
    case simpleString(ByteBuffer)
    case bulkString(ByteBuffer?)
    case error(RedisError)
    case integer(Int)
    case array([RESPValue])

    /// A `NIO.ByteBufferAllocator` for use in creating `.simpleString` and `.bulkString` representations directly, if needed.
    static let allocator = ByteBufferAllocator()

    /// Initializes a `bulkString` value.
    /// - Parameter value: The `String` to store in a `.bulkString` representation.
    public init(bulk value: String) {
        var buffer = RESPValue.allocator.buffer(capacity: value.count)
        buffer.writeString(value)
        self = .bulkString(buffer)
    }

    /// Initializes a `bulkString` value.
    /// - Parameter value: The `Int` value to store in a `.bulkString` representation.
    public init(bulk value: Int) {
        self.init(bulk: value.description)
    }

    /// Stores the representation determined by the `RESPValueConvertible` value.
    /// - Important: If you are sending this value to a Redis server, the type should be convertible to a `.bulkString`.
    /// - Parameter value: The value that needs to be converted and stored in `RESPValue` format.
    public init<Value: RESPValueConvertible>(_ value: Value) {
        self = value.convertedToRESPValue()
    }
}

// MARK: Custom String Convertible

extension RESPValue: CustomStringConvertible {
    /// See `CustomStringConvertible.description`
    public var description: String {
        switch self {
        case let .simpleString(buffer),
             let .bulkString(.some(buffer)):
            guard let value = String(fromRESP: self) else { return "\(buffer)" } // default to ByteBuffer's representation
            return value

        // .integer, .error, and .bulkString(.none) conversions to String always succeed
        case .integer,
             .bulkString(.none):
            return String(fromRESP: self)!
            
        case .null: return "NULL"
        case let .error(e): return e.message
        case let .array(elements): return "[\(elements.map({ $0.description }).joined(separator: ","))]"
        }
    }
}

// MARK: Unwrapped Values

extension RESPValue {
    /// The unwrapped value for `.array` representations.
    /// - Note: This is a shorthand for `Array<RESPValue>.init(fromRESP:)`
    public var array: [RESPValue]? { return [RESPValue](fromRESP: self) }

    /// The unwrapped value as an `Int`.
    /// - Note: This is a shorthand for `Int(fromRESP:)`.
    public var int: Int? { return Int(fromRESP: self) }

    /// Returns `true` if the unwrapped value is `.null`.
    public var isNull: Bool {
        guard case .null = self else { return false }
        return true
    }

    /// The unwrapped `RedisError` that was returned from Redis.
    /// - Note: This is a shorthand for `RedisError(fromRESP:)`.
    public var error: RedisError? { return RedisError(fromRESP: self) }

    /// The unwrapped `NIO.ByteBuffer` for `.simpleString` or `.bulkString` representations.
    public var byteBuffer: ByteBuffer? {
        switch self {
        case let .simpleString(buffer),
             let .bulkString(.some(buffer)): return buffer

        default: return nil
        }
    }
}

// MARK: Conversion Values

extension RESPValue {
    /// The value as a UTF-8 `String` representation.
    /// - Note: This is a shorthand for `String.init(fromRESP:)`.
    public var string: String? { return String(fromRESP: self) }
    
    /// The data stored in either a `.simpleString` or `.bulkString` represented as `Foundation.Data` instead of `NIO.ByteBuffer`.
    /// - Note: This is a shorthand for `Data.init(fromRESP:)`.
    public var data: Data? { return Data(fromRESP: self) }
    
    /// The raw bytes stored in the `.simpleString` or `.bulkString` representations.
    /// - Note: This is a shorthand for `Array<UInt8>.init(fromRESP:)`.
    public var bytes: [UInt8]? { return [UInt8](fromRESP: self) }
}

// MARK: Equatable

extension RESPValue: Equatable {
    public static func == (lhs: RESPValue, rhs: RESPValue) -> Bool {
        switch (lhs, rhs) {
        case (.bulkString(let lhs), .bulkString(let rhs)): return lhs == rhs
        case (.simpleString(let lhs), .simpleString(let rhs)): return lhs == rhs
        case (.integer(let lhs), .integer(let rhs)): return lhs == rhs
        case (.error(let lhs), .error(let rhs)): return lhs == rhs
        case (.array(let lhs), .array(let rhs)): return lhs == rhs
        case (.null, .null): return true
        default: return false
        }
    }
}
