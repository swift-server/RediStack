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

/// Capable of converting to / from `RESPValue`.
public protocol RESPValueConvertible {
    init?(_ value: RESPValue)

    /// Creates a `RESPValue` representation.
    func convertedToRESPValue() -> RESPValue
}

extension RESPValue: RESPValueConvertible {
    public init?(_ value: RESPValue) {
        self = value
    }

    /// See `RESPValueConvertible.convertedToRESPValue()`
    public func convertedToRESPValue() -> RESPValue {
        return self
    }
}

extension RedisError: RESPValueConvertible {
    public init?(_ value: RESPValue) {
        guard let error = value.error else { return nil }
        self = error
    }

    /// See `RESPValueConvertible.convertedToRESPValue()`
    public func convertedToRESPValue() -> RESPValue {
        return .error(self)
    }
}

extension String: RESPValueConvertible {
    public init?(_ value: RESPValue) {
        guard let string = value.string else { return nil }
        self = string
    }

    /// See `RESPValueConvertible.convertedToRESPValue()`
    public func convertedToRESPValue() -> RESPValue {
        return .init(bulk: self)
    }
}

extension FixedWidthInteger {
    public init?(_ value: RESPValue) {
        if let int = value.int {
            self = Self(int)
        } else {
            guard let string = value.string else { return nil }
            guard let int = Self(string) else { return nil }
            self = Self(int)
        }
    }

    /// See `RESPValueConvertible.convertedToRESPValue()`
    public func convertedToRESPValue() -> RESPValue {
        return .init(bulk: self.description)
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
    public init?(_ value: RESPValue) {
        guard let string = value.string else { return nil }
        guard let float = Double(string) else { return nil }
        self = float
    }

    /// See `RESPValueConvertible.convertedToRESPValue()`
    public func convertedToRESPValue() -> RESPValue {
        return .init(bulk: self.description)
    }
}

extension Float: RESPValueConvertible {
    public init?(_ value: RESPValue) {
        guard let string = value.string else { return nil }
        guard let float = Float(string) else { return nil }
        self = float
    }

    /// See `RESPValueConvertible.convertedToRESPValue()`
    public func convertedToRESPValue() -> RESPValue {
        return .init(bulk: self.description)
    }
}

extension Collection where Element: RESPValueConvertible {
    /// See `RESPValueConvertible.convertedToRESPValue()`
    public func convertedToRESPValue() -> RESPValue {
        let elements = map { $0.convertedToRESPValue() }
        let value = elements.withUnsafeBufferPointer {
            ContiguousArray<RESPValue>(UnsafeRawBufferPointer($0).bindMemory(to: RESPValue.self))
        }
        return .array(value)
    }
}

extension Array: RESPValueConvertible where Element: RESPValueConvertible {
    public init?(_ value: RESPValue) {
        guard let array = value.array else { return nil }
        self = array.compactMap { Element($0) }
    }
}

extension ContiguousArray: RESPValueConvertible where Element: RESPValueConvertible {
    public init?(_ value: RESPValue) {
        guard let array = value.array else { return nil }
        self = array.compactMap(Element.init).withUnsafeBytes {
            .init(UnsafeRawBufferPointer($0).bindMemory(to: Element.self))
        }
    }
}

extension Optional: RESPValueConvertible where Wrapped: RESPValueConvertible {
    public init?(_ value: RESPValue) {
        guard !value.isNull else { return nil }
        guard let wrapped = Wrapped(value) else { return nil }

        self = .some(wrapped)
    }

    /// See `RESPValueConvertible.convertedToRESPValue()`.
    public func convertedToRESPValue() -> RESPValue {
        switch self {
        case .none: return .null
        case let .some(value): return value.convertedToRESPValue()
        }
    }
}

import struct Foundation.Data

extension Data: RESPValueConvertible {
    public init?(_ value: RESPValue) {
        guard let data = value.data else { return nil }
        self = data
    }

    public func convertedToRESPValue() -> RESPValue {
        return .bulkString(self.byteBuffer)
    }
}
