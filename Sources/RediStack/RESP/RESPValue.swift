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

import NIOCore

import struct Foundation.Data

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

    /// Stores the representation determined by the `RESPValueConvertible` value.
    /// - Important: If you are sending this value to a Redis server, the type should be convertible to a `.bulkString`.
    /// - Parameter value: The value that needs to be converted and stored in `RESPValue` format.
    @inlinable
    public init<Value: RESPValueConvertible>(from value: Value) {
        self = value.convertedToRESPValue()
    }

    /// A `NIO.ByteBufferAllocator` for use in creating `.simpleString`
    /// and `.bulkString` representations directly, if needed.
    internal static let allocator = ByteBufferAllocator()

    /// Initializes a `bulkString` value.
    /// - Parameter value: The `String` to store in a `.bulkString` representation.
    @usableFromInline
    internal init(bulk value: String?) {
        guard let unwrappedValue = value else {
            self = .bulkString(nil)
            return
        }

        var buffer = RESPValue.allocator.buffer(capacity: unwrappedValue.count)
        buffer.writeString(unwrappedValue)
        self = .bulkString(buffer)
    }

    /// Initializes a `bulkString` value.
    /// - Parameter value: The `Int` value to store in a `.bulkString` representation.
    @usableFromInline
    internal init<Value: FixedWidthInteger>(bulk value: Value?) {
        self.init(bulk: value?.description)
    }
}

// MARK: Custom String Convertible

extension RESPValue: CustomStringConvertible {
    /// See `CustomStringConvertible.description`
    public var description: String {
        switch self {
        case let .simpleString(buffer),
            let .bulkString(.some(buffer)):
            guard let value = String(fromRESP: self) else {
                // default to ByteBuffer's representation
                return "\(buffer)"
            }

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
    public var array: [RESPValue]? { [RESPValue](fromRESP: self) }

    /// The unwrapped value as an `Int`.
    /// - Note: This is a shorthand for `Int(fromRESP:)`.
    public var int: Int? { Int(fromRESP: self) }

    /// Returns `true` if the unwrapped value is `.null`.
    public var isNull: Bool {
        guard case .null = self else { return false }
        return true
    }

    /// The unwrapped `RedisError` that was returned from Redis.
    /// - Note: This is a shorthand for `RedisError(fromRESP:)`.
    public var error: RedisError? { RedisError(fromRESP: self) }

    /// The unwrapped `NIO.ByteBuffer` for `.simpleString` or `.bulkString` representations.
    public var byteBuffer: ByteBuffer? {
        switch self {
        case let .simpleString(buffer),
            let .bulkString(.some(buffer)):
            return buffer

        default: return nil
        }
    }
}

// MARK: Conversion Values

extension RESPValue {
    /// The value as a UTF-8 `String` representation.
    /// - Note: This is a shorthand for `String.init(fromRESP:)`.
    public var string: String? { String(fromRESP: self) }

    /// The data stored in either a `.simpleString` or `.bulkString` represented as `Foundation.Data` instead of `NIO.ByteBuffer`.
    /// - Note: This is a shorthand for `Data.init(fromRESP:)`.
    public var data: Data? { Data(fromRESP: self) }

    /// The raw bytes stored in the `.simpleString` or `.bulkString` representations.
    /// - Note: This is a shorthand for `Array<UInt8>.init(fromRESP:)`.
    public var bytes: [UInt8]? { [UInt8](fromRESP: self) }
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

// MARK: RESPValueConvertible

extension RESPValue: RESPValueConvertible {
    public init?(fromRESP value: RESPValue) {
        self = value
    }

    public func convertedToRESPValue() -> RESPValue {
        self
    }
}

// MARK: EventLoopFuture Extensions

extension EventLoopFuture where Value == RESPValue {
    /// Attempts to convert the resolved RESPValue to the desired type.
    ///
    /// This method is intended to be used much like a precondition in synchronous code, where a value is expected to be available from the `RESPValue`.
    /// - Important: If the `RESPValueConvertible` initializer fails, then the `NIO.EventLoopFuture` will fail.
    /// - Parameter to: The desired type to convert to.
    /// - Throws: `RedisClientError.failedRESPConversion(to:)`
    /// - Returns: A `NIO.EventLoopFuture` that resolves a value of the desired type or fails if the conversion does.
    @usableFromInline
    internal func tryConverting<T: RESPValueConvertible>(
        to type: T.Type = T.self,
        file: StaticString = #file,
        line: UInt = #line
    ) -> EventLoopFuture<T> {
        self.flatMapThrowing {
            guard let value = T(fromRESP: $0) else {
                throw RedisClientError.failedRESPConversion(to: type)
            }
            return value
        }
    }
}

// MARK: RESPValue Collections

extension RangeReplaceableCollection where Element == RESPValue {
    /// Converts the collection of `RESPValueConvertible` elements and appends them to the end of the array.
    /// - Note: This method guarantees that only one storage expansion will happen to copy the elements.
    /// - Parameters elementsToCopy: The collection of elements to convert to `RESPValue` and append to the array.
    public mutating func append<ValueCollection>(convertingContentsOf elementsToCopy: ValueCollection)
    where
        ValueCollection: Collection,
        ValueCollection.Element: RESPValueConvertible
    {
        guard elementsToCopy.count > 0 else { return }

        self.reserveCapacity(self.count + elementsToCopy.count)
        for element in elementsToCopy {
            self.append(element.convertedToRESPValue())
        }
    }

    /// Adds the elements of a collection to this array, delegating the details of how they are added to the given closure.
    ///
    /// When your closure will be doing more than a simple transform of the element value, such as when you're adding both the key _and_ value from a `KeyValuePair`,
    /// you should set the `overestimatedCountBeingAdded` to a value you do not expect to exceed in order to prevent multiple allocations from the increasing
    /// element count.
    ///
    /// For example:
    ///
    ///     let pairs = [
    ///         "MyID": 30,
    ///         "YourID": 31
    ///     ]
    ///     var values: [RESPValue] = []
    ///     values.add(contentsOf: pairs, overestimatedCountBeingAdded: pairs.count * 2) { (array, element) in
    ///         // element is a (key, value) tuple
    ///         array.append(element.0.convertedToRESPValue())
    ///         array.append(element.1.convertedToRESPValue())
    ///     }
    ///
    /// However, if you just want to apply a transform, you can do that more similarly to a call to the `reduce` methods:
    ///
    ///     let valuesToConvert = [...] // some collection of non-`RESPValueConvertible` elements, such as third-party types
    ///     let values: [RESPValue] = []
    ///     values.add(contentsOf: valuesToConvert) { (array, element) in
    ///         // your transform and insert/append implementation
    ///     }
    ///
    /// If the `elementsToCopy` has no elements, the `closure` is never called.
    ///
    /// - Parameters:
    ///     - elementsToCopy: The collection of elements that will be added to the array in the closure.
    ///     - overestimatedCountBeingAdded: The number of elements that will be added to the array.
    ///         If no value is provided, the size of the collection being copied will be used.
    ///     - closure: A closure left to define how the collection's element should be added into the array.
    public mutating func add<ValueCollection: Collection>(
        contentsOf elementsToCopy: ValueCollection,
        overestimatedCountBeingAdded: Int? = nil,
        _ closure: (inout Self, ValueCollection.Element) -> Void
    ) {
        guard elementsToCopy.count > 0 else { return }

        let sizeToAdd = overestimatedCountBeingAdded ?? elementsToCopy.count
        self.reserveCapacity(self.count + sizeToAdd)

        for element in elementsToCopy {
            closure(&self, element)
        }
    }
}

// MARK: Mapping RESPValue Collections

extension Collection where Element == RESPValue {
    /// Maps the elements of the sequence to the type desired.
    /// - Parameter t1: The type to convert the elements to.
    /// - Returns: An array of the results from the conversions.
    @inlinable
    public func map<T: RESPValueConvertible>(as t1: T.Type) -> [T?] {
        self.map(T.init(fromRESP:))
    }

    /// Maps the first element to the type sepcified, with all remaining elements mapped to the second type.
    @inlinable
    public func map<T1, T2>(firstAs t1: T1.Type, remainingAs t2: T2.Type) -> (T1?, [T2?])
    where T1: RESPValueConvertible, T2: RESPValueConvertible {
        guard self.count > 1 else { return (nil, []) }
        let first = self.first.map(T1.init(fromRESP:)) ?? nil
        let remaining = self.dropFirst().map(T2.init(fromRESP:))
        return (first, remaining)
    }

    /// Maps the first and second elements to the types specified, with any remaining mapped to the third type.
    @inlinable
    public func map<T1, T2, T3>(
        firstAs t1: T1.Type,
        _ t2: T2.Type,
        remainingAs t3: T3.Type
    ) -> (T1?, T2?, [T3?])
    where T1: RESPValueConvertible, T2: RESPValueConvertible, T3: RESPValueConvertible {
        guard self.count > 2 else { return (nil, nil, []) }
        let first = self.first.map(T1.init(fromRESP:)) ?? nil
        let second = T2.init(fromRESP: self[self.index(after: self.startIndex)])
        let remaining = self.dropFirst(2).map(T3.init(fromRESP:))
        return (first, second, remaining)
    }

    /// Maps the first, second, and third elements to the types specified, with any remaining mapped to the fourth type.
    @inlinable
    public func map<T1, T2, T3, T4>(
        firstAs t1: T1.Type,
        _ t2: T2.Type,
        _ t3: T3.Type,
        remainingAs t4: T4.Type
    ) -> (T1?, T2?, T3?, [T4?])
    where T1: RESPValueConvertible, T2: RESPValueConvertible, T3: RESPValueConvertible, T4: RESPValueConvertible {
        guard self.count > 3 else { return (nil, nil, nil, []) }

        let firstIndex = self.startIndex
        let secondIndex = self.index(after: firstIndex)
        let thirdIndex = self.index(after: secondIndex)

        let first = T1.init(fromRESP: self[firstIndex])
        let second = T2.init(fromRESP: self[secondIndex])
        let third = T3.init(fromRESP: self[thirdIndex])
        let remaining = self.dropFirst(3).map(T4.init(fromRESP:))

        return (first, second, third, remaining)
    }
}
