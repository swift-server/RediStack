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

import Foundation

// MARK: Inserting RESPValue

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

// MARK: RESPValue Collection mapping

extension Collection where Element == RESPValue {
    /// Maps the elements of the sequence to the type desired.
    /// - Parameter t1: The type to convert the elements to.
    /// - Returns: An array of the results from the conversions.
    @inline(__always)
    public func map<T: RESPValueConvertible>(as t1: T.Type) -> [T?] {
        return self.map(T.init(fromRESP:))
    }
    
    /// Maps the first element to the type sepcified, with all remaining elements mapped to the second type.
    public func map<T1, T2>(firstAs t1: T1.Type, remainingAs t2: T2.Type) -> (T1?, [T2?])
        where T1: RESPValueConvertible, T2: RESPValueConvertible
    {
        guard self.count > 1 else { return (nil, []) }
        let first = self.first.map(T1.init(fromRESP:)) ?? nil
        let remaining = self.dropFirst().map(T2.init(fromRESP:))
        return (first, remaining)
    }
    
    /// Maps the first and second elements to the types specified, with any remaining mapped to the third type.
    public func map<T1, T2, T3>(
        firstAs t1: T1.Type,
        _ t2: T2.Type,
        remainingAs t3: T3.Type
    ) -> (T1?, T2?, [T3?])
        where T1: RESPValueConvertible, T2: RESPValueConvertible, T3: RESPValueConvertible
    {
        guard self.count > 2 else { return (nil, nil, []) }
        let first = self.first.map(T1.init(fromRESP:)) ?? nil
        let second = T2.init(fromRESP: self[self.index(after: self.startIndex)])
        let remaining = self.dropFirst(2).map(T3.init(fromRESP:))
        return (first, second, remaining)
    }
    
    /// Maps the first, second, and third elements to the types specified, with any remaining mapped to the fourth type.
    public func map<T1, T2, T3, T4>(
        firstAs t1: T1.Type,
        _ t2: T2.Type,
        _ t3: T3.Type,
        remainingAs t4: T4.Type
    ) -> (T1?, T2?, T3?, [T4?])
        where T1: RESPValueConvertible, T2: RESPValueConvertible, T3: RESPValueConvertible, T4: RESPValueConvertible
    {
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
