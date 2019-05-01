//===----------------------------------------------------------------------===//
//
// This source file is part of the NIORedis open source project
//
// Copyright (c) 2019 NIORedis project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of NIORedis project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct Foundation.Data
import NIO

extension String {
    @inline(__always)
    var byteBuffer: ByteBuffer {
        var buffer = RESPValue.allocator.buffer(capacity: self.count)
        buffer.writeString(self)
        return buffer
    }
}

/// A representation of a Redis Serialization Protocol (RESP) primitive value.
///
/// See: [https://redis.io/topics/protocol](https://redis.io/topics/protocol)
public enum RESPValue {
    case null
    case simpleString(ByteBuffer)
    case bulkString(ByteBuffer?)
    case error(RedisError)
    case integer(Int)
    case array(ContiguousArray<RESPValue>)

    fileprivate static let allocator = ByteBufferAllocator()

    /// Initializes a `bulkString` by converting the provided string input.
    public init(bulk value: String? = nil) {
        self = .bulkString(value?.byteBuffer)
    }

    public init(bulk value: Int) {
        self = .bulkString(value.description.byteBuffer)
    }

    public init(_ source: RESPValueConvertible) {
        self = source.convertedToRESPValue()
    }
}

// MARK: Expressible by Literals

extension RESPValue: ExpressibleByStringLiteral {
    /// Initializes a bulk string from a String literal
    public init(stringLiteral value: String) {
        self = .bulkString(value.byteBuffer)
    }
}

extension RESPValue: ExpressibleByArrayLiteral {
    /// Initializes an array from an Array literal
    public init(arrayLiteral elements: RESPValue...) {
        self = .array(.init(elements))
    }
}

extension RESPValue: ExpressibleByNilLiteral {
    /// Initializes null from a nil literal
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension RESPValue: ExpressibleByIntegerLiteral {
    /// Initializes an integer from an integer literal
    public init(integerLiteral value: Int) {
        self = .integer(value)
    }
}

// MARK: Computed Values

extension RESPValue {
    /// The `ByteBuffer` storage for either `.simpleString` or `.bulkString` representations.
    public var byteBuffer: ByteBuffer? {
        switch self {
        case let .simpleString(buffer),
             let .bulkString(.some(buffer)): return buffer
        default: return nil
        }
    }

    /// The storage value for `array` representations.
    public var array: ContiguousArray<RESPValue>? {
        guard case .array(let array) = self else { return nil }
        return array
    }

    /// The storage value for `integer` representations.
    public var int: Int? {
        switch self {
        case let .integer(value): return value
        default: return nil
        }
    }

    /// Returns `true` if the value represents a `null` value from Redis.
    public var isNull: Bool {
        switch self {
        case .null: return true
        default: return false
        }
    }

    /// The error returned from Redis.
    public var error: RedisError? {
        switch self {
        case .error(let error): return error
        default: return nil
        }
    }
}

// MARK: Conversion Values

extension RESPValue {
    /// The `RESPValue` converted to a `String`.
    /// - Important: This will always return `nil` from `.error`, `.null`, and `array` cases.
    /// - Note: This creates a `String` using UTF-8 encoding.
    public var string: String? {
        switch self {
        case let .integer(value): return value.description
        case let .simpleString(buffer),
             let .bulkString(.some(buffer)):
            return buffer.getString(at: buffer.readerIndex, length: buffer.readableBytes)

        case .bulkString(.none): return ""
        default: return nil
        }
    }

    /// The raw bytes of the `RESPValue` representation.
    /// - Important: This will always return `nil` from `.error` and `.null` cases.
    public var bytes: [UInt8]? {
        switch self {
        case let .integer(value): return withUnsafeBytes(of: value, RESPValue.copyMemory)
        case let .array(values): return values.withUnsafeBytes(RESPValue.copyMemory)
        case let .simpleString(buffer),
             let .bulkString(.some(buffer)):
            return buffer.getBytes(at: buffer.readerIndex, length: buffer.readableBytes)

        case .bulkString(.none): return []
        default: return nil
        }
    }

    public var data: Data? {
        switch self {
        case let .integer(value): return withUnsafeBytes(of: value, RESPValue.copyMemory)
        case let .array(values): return values.withUnsafeBytes(RESPValue.copyMemory)
        case let .simpleString(buffer),
             let .bulkString(.some(buffer)):
            return buffer.withUnsafeReadableBytes(RESPValue.copyMemory)

        case .bulkString(.none): return Data()
        default: return nil
        }
    }

    // SR-9604
    @inline(__always)
    private static func copyMemory(_ ptr: UnsafeRawBufferPointer) -> Data {
        return Data(UnsafeRawBufferPointer(ptr).bindMemory(to: UInt8.self))
    }
    @inline(__always)
    private static func copyMemory(_ ptr: UnsafeRawBufferPointer) -> [UInt8]? {
        return Array<UInt8>(UnsafeRawBufferPointer(ptr).bindMemory(to: UInt8.self))
    }
}
