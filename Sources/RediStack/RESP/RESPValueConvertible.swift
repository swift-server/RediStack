//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2019 Apple Inc. and the RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct Foundation.Data

/// An object that is capable of being converted to and from `RESPValue` representations arbitrarily.
/// - Important: When conforming your types to be sent to a Redis server, it is expected to always be stored in a `.bulkString` representation. Redis will
/// reject any other `RESPValue` type sent to it.
///
/// Conforming to this protocol only provides convenience methods of translating the Swift type into a `RESPValue` representation within the driver, and references
/// to a `RESPValueConvertible` instance should be short lived for that purpose.
///
/// See `RESPValue`.
public protocol RESPValueConvertible {
    /// Attempts to create a new instance of the conforming type based on the value represented by the `RESPValue`.
    /// - Parameter value: The `RESPValue` representation to attempt to initialize from.
    init?(fromRESP value: RESPValue)

    /// Creates a `RESPValue` representation of the conforming type's value.
    func convertedToRESPValue() -> RESPValue
}

extension String: RESPValueConvertible {
    /// Attempts to provide a UTF-8 representation of the `RESPValue` provided.
    ///
    /// - `.simpleString` and `.bulkString` have their bytes interpeted into a UTF-8 `String`.
    /// - `.integer` displays the ASCII representation (e.g. 30 converts to "30")
    /// - `.error` uses the `RedisError.message`
    ///
    /// See `RESPValueConvertible.init(fromRESP:)`
    public init?(fromRESP value: RESPValue) {
        switch value {
        case let .simpleString(buffer),
            let .bulkString(.some(buffer)):
            guard let string = buffer.getString(at: buffer.readerIndex, length: buffer.readableBytes) else {
                return nil
            }
            self = string

        case .bulkString(.none): self = ""
        case let .integer(value): self = value.description
        case let .error(e): self = e.message
        default: return nil
        }
    }

    public func convertedToRESPValue() -> RESPValue {
        .init(bulk: self)
    }
}

extension FixedWidthInteger {
    /// Attempts to pull an Integer value from the `RESPValue` representation.
    ///
    /// If the value is not an `.integer`, it will attempt to create a `String` representation to then attempt to create an Integer from.
    ///
    /// See `RESPValueConvertible.init(fromRESP:)` and `String.init(fromRESP:)`
    public init?(fromRESP value: RESPValue) {
        if case let .integer(int) = value {
            self = Self(int)
        } else {
            guard
                let string = String(fromRESP: value),
                let int = Self(string)
            else { return nil }
            self = Self(int)
        }
    }

    public func convertedToRESPValue() -> RESPValue {
        .init(bulk: self.description)
    }
}

extension Int: RESPValueConvertible {}
extension Int8: RESPValueConvertible {}
extension Int16: RESPValueConvertible {}
extension Int32: RESPValueConvertible {}
extension Int64: RESPValueConvertible {}
extension UInt: RESPValueConvertible {}
extension UInt8: RESPValueConvertible {}
extension UInt16: RESPValueConvertible {}
extension UInt32: RESPValueConvertible {}
extension UInt64: RESPValueConvertible {}

extension Double: RESPValueConvertible {
    /// Attempts to translate the `RESPValue` as a `Double`.
    ///
    /// This will only succeed if the value is a ASCII representation in a `.simpleString` or `.bulkString`, or is an `.integer`.
    ///
    /// See `RESPValueConvertible.init(fromRESP:)` and `String.init(fromRESP:)`
    public init?(fromRESP value: RESPValue) {
        guard
            let string = String(fromRESP: value),
            let double = Double(string)
        else { return nil }
        self = double
    }

    public func convertedToRESPValue() -> RESPValue {
        .init(bulk: self.description)
    }
}

extension Float: RESPValueConvertible {
    /// Attempts to translate the `RESPValue` as a `Float`.
    ///
    /// This will only succeed if the value is a ASCII representation in a `.simpleString` or `.bulkString`, or is an `.integer`.
    ///
    /// See `RESPValueConvertible.init(fromRESP:)` and `String.init(fromRESP:)`
    public init?(fromRESP value: RESPValue) {
        guard
            let string = String(fromRESP: value),
            let float = Float(string)
        else { return nil }
        self = float
    }

    public func convertedToRESPValue() -> RESPValue {
        .init(bulk: self.description)
    }
}

extension Collection where Element: RESPValueConvertible {
    /// Converts all elements into their `RESPValue` representation, storing all results into a final `.array` representation.
    ///
    /// See `RESPValueConvertible.convertedToRESPValue()`
    public func convertedToRESPValue() -> RESPValue {
        var value: [RESPValue] = []
        value.append(convertingContentsOf: self)
        return .array(value)
    }
}

extension Array: RESPValueConvertible where Element: RESPValueConvertible {
    /// Converts all elements into their Swift type, compacting non-`nil` results into a new `Array`.
    ///
    /// See `RESPValueConvertible.init(fromRESP:)`
    public init?(fromRESP value: RESPValue) {
        guard case let .array(a) = value else { return nil }
        self = a.compactMap(Element.init)
    }
}

extension Array where Element == UInt8 {
    /// Converts the data stored in `.simpleString` and `.bulkString` representations into a raw byte array.
    ///
    /// See `RESPValueConvertible.init(fromRESP:)`
    public init?(fromRESP value: RESPValue) {
        switch value {
        case let .simpleString(buffer),
            let .bulkString(.some(buffer)):
            guard let bytes = buffer.getBytes(at: buffer.readerIndex, length: buffer.readableBytes) else { return nil }
            self = bytes

        case .bulkString(.none): self = []
        default: return nil
        }
    }
}

extension Optional: RESPValueConvertible where Wrapped: RESPValueConvertible {
    /// Translates `.null` into `nil`, otherwise the result of `Wrapped.init(fromRESP:)`.
    ///
    /// See `RESPValueConvertible.init(fromRESP:)`
    public init?(fromRESP value: RESPValue) {
        guard !value.isNull else { return nil }
        guard let wrapped = Wrapped(fromRESP: value) else { return nil }

        self = .some(wrapped)
    }

    /// Creates a `.null` representation when `nil`, otherwise the result of `Wrapped.convertedToRESPValue()`.
    ///
    /// See `RESPValueConvertible.convertedToRESPValue()`
    public func convertedToRESPValue() -> RESPValue {
        switch self {
        case .none: return .null
        case let .some(value): return value.convertedToRESPValue()
        }
    }
}

extension Data: RESPValueConvertible {
    public init?(fromRESP value: RESPValue) {
        switch value {
        case let .simpleString(buffer),
            let .bulkString(.some(buffer)):
            self = Data(buffer.readableBytesView)

        case .bulkString(.none): self = Data()
        default: return nil
        }
    }

    public func convertedToRESPValue() -> RESPValue {
        var buffer = RESPValue.allocator.buffer(capacity: self.count)
        buffer.writeBytes(self)
        return .bulkString(buffer)
    }
}
