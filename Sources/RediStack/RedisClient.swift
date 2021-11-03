//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2019-2020 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import protocol Foundation.LocalizedError
import struct Logging.Logger
import NIO

// - Important: Any RedisClient defined by RediStack should conform to the RedisClientWithUserContext protocol as well

/// An object capable of sending commands and receiving responses.
///
///     let client = ...
///     let result = client.send(command: "GET", arguments: ["my_key"])
///     // result == EventLoopFuture<RESPValue>
///
/// For the full list of available commands, see [https://redis.io/commands](https://redis.io/commands)
public protocol RedisClient {
    /// The `NIO.EventLoop` that this client operates on.
    var eventLoop: EventLoop { get }

    /// Sends the given command to Redis.
    /// - Parameter command: The command to send to Redis for execution.
    /// - Returns: A `NIO.EventLoopFuture` that will resolve when the Redis command receives a response.
    ///
    ///     If a `RedisError` is returned, the future will be failed instead.
    func send<CommandResult>(_ command: RedisCommand<CommandResult>) -> EventLoopFuture<CommandResult>
    
    /// Temporarily overrides the default logger for command logs to the provided instance.
    /// - Parameter logger: The `Logging.Logger` instance to use for command logs.
    /// - Returns: A RedisClient with the temporary override for command logging.
    func logging(to logger: Logger) -> RedisClient
    
    /// Subscribes the client to the specified Redis channels, invoking the provided message receiver each time a message is published.
    ///
    /// See [SUBSCRIBE](https://redis.io/commands/subscribe)
    /// - Important: This will establish the client in a "PubSub mode" where only a specific list of commands are allowed to be executed.
    ///
    ///     Commands issued with this client outside of that list will resolve with failures.
    ///
    ///     See the [PubSub specification](https://redis.io/topics/pubsub)
    /// - Parameters:
    ///     - channels: The names of channels to subscribe to.
    ///     - receiver: A closure which will be invoked each time a channel with a name in `channels` publishes a message.
    ///     - subscribeHandler: An optional closure to be invoked when the subscription becomes active.
    ///     - unsubscribeHandler: An optional closure to be invoked when the subscription becomes inactive.
    /// - Returns: A notification `NIO.EventLoopFuture` that resolves once the subscription has been registered with Redis.
    func subscribe(
        to channels: [RedisChannelName],
        messageReceiver receiver: @escaping RedisSubscriptionMessageReceiver,
        onSubscribe subscribeHandler: RedisSubscriptionChangeHandler?,
        onUnsubscribe unsubscribeHandler: RedisSubscriptionChangeHandler?
    ) -> EventLoopFuture<Void>

    /// Subscribes the client to the specified Redis channel name patterns, invoking the provided message receiver each time a message is published to
    /// a matching channel.
    ///
    ///- Note: If the client is also subscribed to a channel directly by name which also matches a pattern, both subscription message receivers will be invoked.
    ///
    /// See [PSUBSCRIBE](https://redis.io/commands/psubscribe)
    /// - Important: This will establish the client in a "PubSub mode" where only a specific list of commands are allowed to be executed.
    ///
    ///     Commands issues with this client outside of that list will resolve with failures.
    ///
    ///     See the [PubSub specification](https://redis.io/topics/pubsub)
    /// - Parameters:
    ///     - patterns: A list of glob patterns used for matching against PubSub channel names to subscribe to.
    ///     - receiver: A closure which will be invoked each time a channel with a name matching the specified pattern(s) publishes a message.
    ///     - subscribeHandler: An optional closure to be invoked when the subscription becomes active.
    ///     - unsubscribeHandler: An optional closure to be invoked when the subscription becomes inactive.
    /// - Returns: A notification `NIO.EventLoopFuture` that resolves once the subscription has been registered with Redis.
    func psubscribe(
        to patterns: [String],
        messageReceiver receiver: @escaping RedisSubscriptionMessageReceiver,
        onSubscribe subscribeHandler: RedisSubscriptionChangeHandler?,
        onUnsubscribe unsubscribeHandler: RedisSubscriptionChangeHandler?
    ) -> EventLoopFuture<Void>
    
    /// Unsubscribes the client from a specific Redis channel from receiving any future published messages.
    ///
    /// See [UNSUBSCRIBE](https://redis.io/commands/unsubscribe)
    /// - Note: If the channel was not subscribed to with `subscribe(to:messageReceiver:onSubscribe:onUnsubscribe:)`,
    ///     then this method has no effect.
    /// - Important: If no more subscriptions (pattern or channel) are active on the client, the client will be taken out of its "PubSub mode".
    ///
    ///     It will then be allowed to use any command like normal.
    ///
    ///     See the [PubSub specification](https://redis.io/topics/pubsub)
    /// - Parameter channels: A list of channel names to be unsubscribed from.
    /// - Returns: A notification `NIO.EventLoopFuture` that resolves once the subscription(s) have been removed from Redis.
    func unsubscribe(from channels: [RedisChannelName]) -> EventLoopFuture<Void>
    
    /// Unsubscribes the client from a pattern of Redis channel names from receiving any future published messages.
    ///
    /// See [PUNSUBSCRIBE](https://redis.io/commands/punsubscribe)
    /// - Note: This method does not unsubscribe subscriptions made with `subscribe(to:messageReceiver:onSubscribe:onUnsubscribe:)`.
    /// - Important: If no more subscriptions (pattern or channel) are active on the client, the client will be taken out of its "PubSub mode".
    ///
    ///     It will then be allowed to use any command like normal.
    ///
    ///     See the [PubSub specification](https://redis.io/topics/pubsub)
    /// - Parameter patterns: A list of glob patterns to be unsubscribed from.
    /// - Returns: A notification `NIO.EventLoopFuture` that resolves once the subscription(s) have been removed from Redis.
    func punsubscribe(from patterns: [String]) -> EventLoopFuture<Void>
}

// MARK: Extension Methods

extension RedisClient {
    /// Unsubscribes the client from all active Redis channel name subscriptions.
    /// - Returns: A `NIO.EventLoopFuture` that resolves when the subscriptions have been removed.
    public func unsubscribe() -> EventLoopFuture<Void> {
        return self.unsubscribe(from: [])
    }
    
    /// Unsubscribes the client from all active Redis channel name patterns subscriptions.
    /// - Returns: A `NIO.EventLoopFuture` that resolves when the subscriptions have been removed.
    public func punsubscribe() -> EventLoopFuture<Void> {
        return self.punsubscribe(from: [])
    }
}

// MARK: Overloads

extension RedisClient {
    public func unsubscribe(from channels: RedisChannelName...) -> EventLoopFuture<Void> {
        return self.unsubscribe(from: channels)
    }

    public func punsubscribe(from patterns: String...) -> EventLoopFuture<Void> {
        return self.punsubscribe(from: patterns)
    }

    public func subscribe(
        to channels: [RedisChannelName],
        messageReceiver receiver: @escaping RedisSubscriptionMessageReceiver,
        onSubscribe subscribeHandler: RedisSubscriptionChangeHandler? = nil,
        onUnsubscribe unsubscribeHandler: RedisSubscriptionChangeHandler? = nil
    ) -> EventLoopFuture<Void> {
        return self.subscribe(to: channels, messageReceiver: receiver, onSubscribe: subscribeHandler, onUnsubscribe: unsubscribeHandler)
    }

    public func subscribe(
        to channels: RedisChannelName...,
        messageReceiver receiver: @escaping RedisSubscriptionMessageReceiver,
        onSubscribe subscribeHandler: RedisSubscriptionChangeHandler? = nil,
        onUnsubscribe unsubscribeHandler: RedisSubscriptionChangeHandler? = nil
    ) -> EventLoopFuture<Void> {
        return self.subscribe(to: channels, messageReceiver: receiver, onSubscribe: subscribeHandler, onUnsubscribe: unsubscribeHandler)
    }

    public func psubscribe(
        to patterns: [String],
        messageReceiver receiver: @escaping RedisSubscriptionMessageReceiver,
        onSubscribe subscribeHandler: RedisSubscriptionChangeHandler? = nil,
        onUnsubscribe unsubscribeHandler: RedisSubscriptionChangeHandler? = nil
    ) -> EventLoopFuture<Void> {
        return self.psubscribe(to: patterns, messageReceiver: receiver, onSubscribe: subscribeHandler, onUnsubscribe: unsubscribeHandler)
    }

    public func psubscribe(
        to patterns: String...,
        messageReceiver receiver: @escaping RedisSubscriptionMessageReceiver,
        onSubscribe subscribeHandler: RedisSubscriptionChangeHandler? = nil,
        onUnsubscribe unsubscribeHandler: RedisSubscriptionChangeHandler? = nil
    ) -> EventLoopFuture<Void> {
        return self.psubscribe(to: patterns, messageReceiver: receiver, onSubscribe: subscribeHandler, onUnsubscribe: unsubscribeHandler)
    }
}

// MARK: Errors

/// When working with `RedisClient`, runtime errors can be thrown to indicate problems with connection state, decoding assertions, or otherwise.
public struct RedisClientError: LocalizedError, Equatable, Hashable {
    /// The connection is closed, but was used to try and send a command to Redis.
    public static let connectionClosed = RedisClientError(.connectionClosed)
    /// A race condition was triggered between unsubscribing from the last target while subscribing to a new target.
    public static let subscriptionModeRaceCondition = RedisClientError(.subscriptionModeRaceCondition)
    /// A connection that is not authorized for PubSub subscriptions attempted to create a subscription.
    public static let pubsubNotAllowed = RedisClientError(.pubsubNotAllowed)
    
    /// Conversion from `RESPValue` to the specified type failed.
    ///
    /// If this is ever triggered, please capture the original `RESPValue` string sent from Redis for bug reports.
    public static func failedRESPConversion(to type: Any.Type) -> RedisClientError {
        return .init(.failedRESPConversion(to: type))
    }
    
    /// Expectations of message structures were not met.
    ///
    /// If this is ever triggered, please capture the original `RESPValue` string sent from Redis along with the command and arguments sent to Redis for bug reports.
    public static func assertionFailure(message: String) -> RedisClientError {
        return .init(.assertionFailure(message: message))
    }
    
    public var errorDescription: String? {
        let message: String
        switch self.baseError {
        case .connectionClosed: message = "trying to send command with a closed connection"
        case let .failedRESPConversion(type): message = "failed to convert RESP to \(type)"
        case let .assertionFailure(text): message = text
        case .subscriptionModeRaceCondition: message = "received request to subscribe after subscription mode has ended"
        case .pubsubNotAllowed: message = "connection attempted to create a PubSub subscription"
        }
        return "(RediStack) \(message)"
    }
    
    public var recoverySuggestion: String? {
        switch self.baseError {
        case .connectionClosed: return "Check that the connection is not closed before invoking commands. With RedisConnection, this can be done with the 'isConnected' property."
        case .failedRESPConversion: return "Ensure that the data type being requested is actually what's being returned. If you see this error and are not sure why, capture the original RESPValue string sent from Redis to add to your bug report."
        case .assertionFailure: return "This error should in theory never happen. If you trigger this error, capture the original RESPValue string sent from Redis along with the command and arguments that you sent to Redis to add to your bug report."
        case .subscriptionModeRaceCondition: return "This is a race condition where the PubSub handler was removed after a subscription was being added, but before it was committed. This can be solved by just retrying the subscription."
        case .pubsubNotAllowed: return "When connections are managed by a pool, they are not allowed to create PubSub subscriptions on their own. Use the appropriate PubSub commands on the connection pool itself. If the connection is not managed by a pool, this is a bug and should be reported."
        }
    }
    
    private var baseError: BaseError
    
    private init(_ baseError: BaseError) { self.baseError = baseError }
    
    /* Protocol Conformances and Private Type implementation */
    
    public static func ==(lhs: RedisClientError, rhs: RedisClientError) -> Bool {
        return lhs.localizedDescription == rhs.localizedDescription
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.localizedDescription)
    }
    
    fileprivate enum BaseError {
        case connectionClosed
        case failedRESPConversion(to: Any.Type)
        case assertionFailure(message: String)
        case subscriptionModeRaceCondition
        case pubsubNotAllowed
    }
}
