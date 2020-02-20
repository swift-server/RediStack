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
    public init(bulk value: String?) {
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
    public init<Value: FixedWidthInteger>(bulk value: Value?) {
        self.init(bulk: value?.description)
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

// MARK: RESPValueConvertible

extension RESPValue: RESPValueConvertible {
    public init?(fromRESP value: RESPValue) {
        self = value
    }

    public func convertedToRESPValue() -> RESPValue {
        return self
    }
}

// MARK: EventLoopFuture Extensions

import NIO

extension EventLoopFuture where Value == RESPValue {
    /// Attempts to convert the `RESPValue` to the desired `RESPValueConvertible` type.
    /// If the `RESPValueConvertible.init(_:)` returns `nil`, then the `EventLoopFuture` will fail.
    /// - Parameter to: The desired type to convert to.
    /// - Returns: An `EventLoopFuture` that resolves a value of the desired type.
    @inlinable
    public func convertFromRESPValue<T>(
        to type: T.Type = T.self,
        file: StaticString = #function,
        function: StaticString = #function,
        line: UInt = #line
    )
        -> EventLoopFuture<T> where T: RESPValueConvertible
    {
        return self.flatMapThrowing {
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
        elementsToCopy.forEach { self.append($0.convertedToRESPValue()) }
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
        
        elementsToCopy.forEach { closure(&self, $0) }
    }
}
