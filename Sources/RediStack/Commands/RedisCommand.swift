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

/// An abstract representation of a Redis command that can be sent to a Redis instance.
///
/// An instance will retain the keyword of the command in plaintext as a `String` for identity purposes,
/// while all the arguments will be stored as `RESPValue` representations.
///
/// Each `RedisCommand` has a generic type referred to as `ResultType` that is the native Swift representation
/// of the final result type parsed from the Redis command response.
///
/// When creating a `RedisCommand`, a closure is provided for transforming an arbitrary `RESPValue` instance into the `ResultType`.
public struct RedisCommand<ResultType> {
    public let keyword: String
    public let arguments: [RESPValue]
    
    internal let transform: (RESPValue) throws -> ResultType

    /// Creates a command with the given details that represents a Redis command in Swift.
    /// - Warning: The `transform` closure is escaping, and will retain references to any scope captures.
    /// - Parameters:
    ///     - keyword: The command keyword as defined by Redis.
    ///     - arguments: The command arguments to be sent to Redis.
    ///     - transform: The closure to invoke to transform the value from its raw `RESPValue` instance to the desired final `ResultType`.
    public init(
        keyword: String,
        arguments: [RESPValue],
        mapValueToResult transform: @escaping (RESPValue) throws -> ResultType
    ) {
        self.keyword = keyword
        self.arguments = arguments
        self.transform = transform
    }

    /// Serializes the entire command into a single value for sending to Redis.
    /// - Returns: A `RESPValue.array` value of the keyword and its arguments.
    public func serialized() -> RESPValue {
        var message: [RESPValue] = [.init(bulk: self.keyword)]
        message.append(contentsOf: self.arguments)
        return .array(message)
    }
}

extension RedisCommand where ResultType == RESPValue {
    /// Creates a command with the given keyword and arguments.
    public init(keyword: String, arguments: [RESPValue]) {
        self.init(keyword: keyword, arguments: arguments, mapValueToResult: { $0 })
    }
}

extension RedisCommand where ResultType: RESPValueConvertible {
    /// Creates a command that tries to map the Redis response to the result type.
    public init(keyword: String, arguments: [RESPValue]) {
        self.init(keyword: keyword, arguments: arguments, mapValueToResult: { try $0.map(to: ResultType.self) })
    }
}

extension RedisCommand where ResultType == Bool {
    @usableFromInline
    internal init(keyword: String, arguments: [RESPValue]) {
        self.init(keyword: keyword, arguments: arguments, mapValueToResult: {
            let result = try $0.map(to: Int.self)
            return result == 1
        })
    }
}

extension RedisCommand where ResultType == Void {
    /// Creates a command that ignores the response from Redis acting as a completion notification.
    public init(keyword: String, arguments: [RESPValue]) {
        self.init(keyword: keyword, arguments: arguments, mapValueToResult: { _ in })
    }
}


// MARK: Equatable
extension RedisCommand: Equatable {
    public static func ==<T>(lhs: RedisCommand<T>, rhs: RedisCommand<T>) -> Bool {
        return lhs.keyword == rhs.keyword && lhs.arguments == rhs.arguments
    }
}

// MARK: - Common helpers

extension RedisCommand {
    @usableFromInline
    internal static func _scan<T>(
        keyword: String,
        _ key: RedisKey?,
        _ pos: Int,
        _ match: String?,
        _ count: Int?,
        _ transform: @escaping (RESPValue) throws -> T
    ) -> RedisCommand<(Int, T)> {
        var args: [RESPValue] = [.init(bulk: pos)]
        
        if let k = key { args.insert(.init(from: k), at: 0) }
        if let m = match { args.append(contentsOf: [.init(bulk: "match"), .init(bulk: "\(m)")]) }
        if let c = count { args.append(contentsOf: [.init(bulk: "count"), .init(bulk: "\(c)")]) }
        
        return .init(keyword: keyword, arguments: args) {
            let response = try $0.map(to: [RESPValue].self)
            assert(response.count >= 2, "Received response of unexpected size: \(response)")
            
            let position = try response[0].map(to: Int.self)
            let elements = try transform(response[1])

            return (position, elements)
        }
    }
}
