//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2020-2022 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct Logging.Logger
import NIO
import RediStack

extension RedisClient {
    /// Creates a `RedisSet` reference to the value stored at `key` with values of the type specificed.
    ///
    ///     let setOfIDs = client.makeSetReference(key: "ids", type: Int.self)
    ///     // setOfIDs represents a Set of `Int`.
    ///
    /// - Parameters:
    ///     - key: The Redis key to identify the Set.
    ///     - type: The Swift type representation of the elements in the set.
    /// - Returns: A `RedisSet` for repeatedly interacting with a specific Set value in Redis.
    public func makeSet<Element>(key: RedisKey, type: Element.Type = Element.self) -> RedisSet<Element> {
        return RedisSet(identifier: key, client: self)
    }
}

extension RedisError {
    // The verbatim message from Redis for index out of range errors to use in shortcutting network requests.
    internal static let indexOutOfRange = RedisError(reason: "ERR index out of range")
}

/// A convenience object that references a specific Set value type in a Redis instance.
///
/// The main purpose of this object is if you have a persistent Set value stored in Redis that you will need to reference several times - such as an index.
///
/// It will allow you to give it a reusable `RediStack.RedisClient` and an ID to handle the proper calls to the client to fetch the desired data in the key.
///
/// Ideally, working with a `RedisSet` should feel as familiar as any other Swift `Collection`.
///
///     let client = ...
///     let userIDSet = RedisSet<Int>(identifier: "users_ids", client: client)
///     let count = userIDSet.insert(30).flatMap { _ in userIDSet.count }.wait()
///     print(count) // Int(1)
///
/// - Note: Use of `.wait()` in the example is for simplicity.. Never call `.wait()` on a `NIO.EventLoop`!
///
/// - Important: `RedisSet<T>` instances have _reference_ semantics,
///     as it holds a reference to a `RediStack.RedisClient` existential which could be a class.
///
///     It is also important to note that this will retain that instance in reference counts.
///
/// See [https://redis.io/topics/data-types-intro#sets](https://redis.io/topics/data-types-intro#sets)
public struct RedisSet<Element> where Element: RESPValueConvertible {
    /// The key in Redis that this instance is a reference to.
    public var identifier: RedisKey { return self.id }
    
    private let id: RedisKey
    private let client: RedisClient
    private let eventLoop: EventLoop
    private let logger: Logger?
    
    /// Initializes a new reference to a specific Redis key that holds a Set value type.
    /// - Parameters:
    ///     - identifier: The key identifier to reference this set.
    ///     - client: The `RediStack.RedisClient` to use for making calls to Redis.
    ///     - eventLoop: An optional event loop to hop to for any further chaining on returned event loop futures.
    ///     - logger: An optional logger instance to use for logs generated from commands.
    public init(identifier: RedisKey, client: RedisClient, eventLoop: EventLoop? = nil, logger: Logger? = nil) {
        self.id = identifier
        self.client = client
        self.eventLoop = eventLoop ?? client.eventLoop
        self.logger = logger
    }

    private func send<CommandResult>(_ command: RedisCommand<CommandResult>) -> EventLoopFuture<CommandResult> {
        return self.client.send(command, eventLoop: self.eventLoop, logger: self.logger)
    }
    
    /// Resolves the number of elements in the set.
    ///
    /// See `RediStack.RedisClient.scard(of:)`
    public var count: EventLoopFuture<Int> { return self.send(.scard(of: self.id)) }
    /// Resolves a Boolean value that indicates whether the set is empty.
    public var isEmpty: EventLoopFuture<Bool> { return self.count.map { $0 == 0 } }
    /// Resolves all of elements in the set.
    ///
    /// All member elements will be converted into the type `Element`, based on its conformance to `RediStack.RESPValueConvertible`.
    /// All `nil` values will be filtered from the result.
    ///
    /// See `RediStack.RedisClient.smembers(of:)`
    public var allElements: EventLoopFuture<[Element]> {
        return self.send(.smembers(of: self.id))
            .map { $0.compactMap(Element.init) }
    }
    
    /// Resolves a Boolean value that indicates whether the given element exists in the set.
    ///
    /// See `RediStack.RedisClient.sismember(_:of:)`
    /// - Parameter member: An element to look for in the set.
    /// - Returns: A `NIO.EventLoopFuture<Bool>` resolving `true` if `member` exists in the set; otherwise, `false`.
    public func contains(_ member: Element) -> EventLoopFuture<Bool> {
        return self.send(.sismember(member, of: self.id))
    }
}

// MARK: Inserting Elements

extension RedisSet {
    /// Inserts the given element(s) in the set if it is not already present.
    ///
    /// See `RediStack.RedisClient.sadd(_:to:)`
    /// - Parameter newMember: An element to insert into the set.
    /// - Returns: A `NIO.EventLoopFuture<Bool>` resolving `true` if `newMember` was inserted into the set; otherwise, `false`.
    public func insert(_ newMember: Element) -> EventLoopFuture<Bool> {
        return self.insert(contentsOf: [newMember])
            .map { $0 == 1 }
    }
    
    /// Inserts the elements of an array into the set that do not already exist.
    ///
    /// See `RediStack.RedisClient.sadd(_:to:)`
    /// - Parameter newMembers: The elements to insert into the set.
    /// - Returns: A `NIO.EventLoopFuture<Int>` resolving the number of elements inserted into the set.
    public func insert(contentsOf newMembers: [Element]) -> EventLoopFuture<Int> {
        guard newMembers.count > 0 else { return self.eventLoop.makeSucceededFuture(0) }
        return self.send(.sadd(newMembers, to: self.id))
    }
}

// MARK: Removing Elements

extension RedisSet {
    /// Moves the given element from the current set to the other given set.
    ///
    /// See `RediStack.RedisClient.smove(_:from:to:)`
    /// - Parameters:
    ///     - member: The element in the set to move.
    ///     - other:A set of the same type as the current set.
    /// - Returns: A `NIO.EventLoopFuture<Bool>` resolving `true` if the element was moved; otherwise, `false`.
    public func move(_ member: Element, to other: RedisSet<Element>) -> EventLoopFuture<Bool> {
        return self.send(.smove(member, from: self.id, to: other.id))
    }
    
    /// Removes the given element from the set.
    ///
    /// See `RediStack.RedisClient.srem(_:from:)`
    /// - Parameter members: The element in the set to remove.
    /// - Returns: A `NIO.EventLoopFuture<Bool>` resolving `true` if `member` was removed from the set; otherwise, `false`.
    public func remove(_ member: Element) -> EventLoopFuture<Bool> {
        return self.remove([member])
            .map { $0 == 1 }
    }
    
    /// Removes the given elements from the set.
    ///
    /// See `RediStack.RedisClient.srem(_:from:)`
    /// - Parameter members: The elements to remove from the set.
    /// - Returns: A `NIO.EventLoopFuture<Int>` resolving the number of elements removed from the set.
    public func remove(_ members: [Element]) -> EventLoopFuture<Int> {
        guard members.count > 0 else { return self.eventLoop.makeSucceededFuture(0) }
        return self.send(.srem(members, from: self.id))
    }
    
    /// Removes all elements from the array.
    ///
    /// See `RediStack.RedisClient.delete(_:)`
    /// - Returns: A `NIO.EventLoopFuture<Bool>` resolving `true` if all elements were removed; otherwise, `false`.
    public func removeAll() -> EventLoopFuture<Bool> {
        return self.client.delete([self.id], eventLoop: self.eventLoop, logger: self.logger)
            .map { $0 == 1 }
    }
}

// MARK: Random Elements

extension RedisSet {
    /// Removes and resolves a random element in the set.
    ///
    /// See `RediStack.RedisClient.spop(from:)`
    ///
    /// - Note: This will convert a `RESPValue` response into the `Element`, depending on its conformance to `RESPValueConvertible`.
    /// If the conversion fails, the resolved value will be `nil`.
    ///
    /// - Returns: A `NIO.EventLoopFuture<Element?>` resolving a randomly popped element from the set, or `nil` if the set was empty.
    public func popRandomElement() -> EventLoopFuture<Element?> {
        return self.send(.spop(from: self.id))
            .map { response in
                guard response.count > 0 else { return nil }
                return Element(fromRESP: response[0])
            }
    }
    
    /// Removes and resolves multiple elements from the set, up to the given `max` count.
    ///
    /// See `RediStack.RedisClient.spop(from:max:)`
    ///
    /// - Note: This will convert the elements from `RESPValue` representations into the `Element`, depending on its conformance to `RESPValueConvertible`.
    /// `nil` values from the conversion will be filtered from the resolved result.
    /// - Parameter count: The max number of elements that should be popped from the set.
    /// - Returns: A `NIO.EventLoopFuture<[Element]>` resolving between `0` and `max` count of random elements in the set.
    public func popRandomElements(max count: Int) -> EventLoopFuture<[Element]> {
        guard count >= 0 else { return self.eventLoop.makeFailedFuture(RedisError.indexOutOfRange) }
        guard count >= 1 else { return self.eventLoop.makeSucceededFuture([]) }
        return self.send(.spop(from: self.id, max: count))
            .map { return $0.compactMap(Element.init) }
    }
    
    /// Resolves a random element in the set.
    ///
    /// See `RediStack.RedisClient.srandmember(from:max:)`
    ///
    /// - Note: This will convert a `RESPValue` response into the `Element`, depending on its conformance to `RESPValueConvertible`.
    /// If the conversion fails, the resolved value will be `nil`.
    ///
    /// - Returns: A `NIO.EventLoopFuture<Element?>` resolving a randoml element from the set, or `nil` if the set was empty.
    public func randomElement() -> EventLoopFuture<Element?> {
        return self.send(.srandmember(from: self.id))
            .map { response in
                guard response.count > 0 else { return nil }
                return Element(fromRESP: response[0])
            }
    }
    
    /// Resolves multiple elements from the set, up to the given `max` count.
    ///
    ///     // assume `intSet` has 3 elements
    ///     let intSet: RedisSet<Int> = ...
    ///
    ///     // returns all 3 elements
    ///     intSet.random(max: 4, allowDuplicates: false)
    ///     // returns 4 elements, with a duplicate
    ///     intSet.random(max: 4, allowDuplicates: true)
    ///
    /// See `RediStack.RedisClient.srandmember(from:max:)`
    ///
    /// - Note: This will convert the elements from `RESPValue` representations into the `Element`, depending on its conformance to `RESPValueConvertible`.
    /// `nil` values from the conversion will be filtered from the resolved result.
    /// - Parameters:
    ///     - max: The max number of elements to select, as available.
    ///     - allowDuplicates: Should duplicate elements be picked?
    /// - Returns: A `NIO.EventLoopFuture<[Element]>` resolving between `0` and `max` count of random elements in the set.
    public func randomElements(max: Int, allowDuplicates: Bool = false) -> EventLoopFuture<[Element]> {
        assert(max > 0, "Max should be a positive value. Use 'allowDuplicates' to handle proper value signing.")

        let count = allowDuplicates ? -max : max
        return self.send(.srandmember(from: self.id, max: count))
            .map { $0.compactMap(Element.init) }
    }
}
