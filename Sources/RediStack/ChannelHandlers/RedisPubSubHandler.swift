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

import NIO

/// A closure receiver of individual Pub/Sub messages from Redis subscriptions to channels and patterns.
/// - Warning: The receiver is called on the same `NIO.EventLoop` that processed the message.
///
///     If you are doing non-trivial work in response to PubSub messages, it is **highly recommended** that the work be dispatched to another thread
///     so as to not block further messages from being processed.
/// - Parameters:
///     - publisher: The name of the channel that published the message.
///     - message: The message data that was received from the `publisher`.
public typealias RedisSubscriptionMessageReceiver = (_ publisher: RedisChannelName, _ message: RESPValue) -> Void

/// The details of the subscription change.
/// - Parameters:
///     - subscriptionKey: The subscribed channel or pattern that had its subscription status changed.
///     - currentSubscriptionCount: The current total number of subscriptions the connection has.
public typealias RedisSubscriptionChangeDetails = (subscriptionKey: String, currentSubscriptionCount: Int)

/// A closure handler invoked for Pub/Sub subscribe commands.
///
/// This closure will be invoked only *once* for each individual channel or pattern that is having its subscription changed,
/// even if it was done as a single PSUBSCRIBE or SUBSCRIBE command.
/// - Warning: The receiver is called on the same `NIO.EventLoop` that processed the message.
///
///     If you are doing non-trivial work in response to PubSub messages, it is **highly recommended** that the work be dispatched to another thread
///     so as to not block further messages from being processed.
/// - Parameter details: The details of the subscription.
public typealias RedisSubscribeHandler = (_ details: RedisSubscriptionChangeDetails) -> Void

/// An enumeration of possible sources of Pub/Sub unsubscribe events.
public enum RedisUnsubscribeEventSource {
    /// The client sent an unsubscribe command either as UNSUBSCRIBE or PUNSUBSCRIBE.
    case userInitiated
    /// The client encountered an error and had to unsubscribe.
    /// - Parameter _: The error the client encountered.
    case clientError(_ error: Error)
}

/// A closure handler invoked for Pub/Sub unsubscribe commands.
///
/// This closure will be invoked only *once* for each individual channel or pattern that is having its subscription changed,
/// even if it was done as a single PUNSUBSCRIBE or UNSUBSCRIBE command.
/// - Warning: The receiver is called on the same `NIO.EventLoop` that processed the message.
///
///     If you are doing non-trivial work in response to PubSub messages, it is **highly recommended** that the work be dispatched to another thread
///     so as to not block further messages from being processed.
/// - Parameters:
///     - details: The details of the subscription.
///     - source: The source of the unsubscribe event.
public typealias RedisUnsubscribeHandler = (_ details: RedisSubscriptionChangeDetails, _ source: RedisUnsubscribeEventSource) -> Void

/// A list of patterns or channels that a Pub/Sub subscription change is targetting.
///
/// See `RedisChannelName`, [PSUBSCRIBE](https://redis.io/commands/psubscribe) and [SUBSCRIBE](https://redis.io/commands/subscribe)
///
/// Use the `values` property to quickly access the underlying list of the target for any purpose that requires a the `String` values.
public enum RedisSubscriptionTarget: Equatable, CustomDebugStringConvertible {
    case channels([RedisChannelName])
    case patterns([String])

    public var values: [String] {
        switch self {
        case let .channels(names): return names.map { $0.rawValue }
        case let .patterns(values): return values
        }
    }
    
    public var debugDescription: String {
        let values = self.values.joined(separator: ", ")
        switch self {
        case .channels: return "Channels '\(values)'"
        case .patterns: return "Patterns '\(values)'"
        }
    }
    
    public static func ==(lhs: RedisSubscriptionTarget, rhs: RedisSubscriptionTarget) -> Bool {
        switch (lhs, rhs) {
        case let (.channels(left), .channels(right)): return left == right
        case let (.patterns(left), .patterns(right)): return left == right
        default: return false
        }
    }
}

/// A channel handler that stores a map of closures and channel or pattern names subscribed to in Redis using Pub/Sub.
///
/// These `RedisPubSubMessageReceiver` closures are added and removed using methods directly on an instance of this handler.
///
/// When a receiver is added or removed, the handler will send the appropriate subscribe or unsubscribe message to Redis so that the connection
/// reflects the local Channel state.
///
/// # ChannelInboundHandler
/// This handler is designed to be placed _before_ a `RedisCommandHandler` so that it can intercept Pub/Sub messages and dispatch them to the appropriate
/// receiver.
///
/// If a response is not in the Pub/Sub message format as specified by Redis, then it is treated as a normal Redis command response and sent further into
/// the pipeline so that eventually a `RedisCommandHandler` can process it.
///
/// # ChannelOutboundHandler
/// This handler is what is defined as a "transparent" `NIO.ChannelOutboundHandler` in that it does absolutely nothing except forward outgoing commands
/// in the pipeline.
///
/// The reason why this handler needs to conform to this protocol at all, is that subscribe and unsubscribe commands are executed outside of a normal
/// `NIO.Channel.write(_:)` cycle, as message receivers aren't command arguments and need to be stored.
///
/// All of this is outside the responsibility of the `RedisCommandHandler`,
/// so the `RedisPubSubHandler` uses its own `NIO.ChannelHandlerContext` being before the command handler to short circuit the pipeline.
///
/// # RemovableChannelHandler
/// As a connection can move in and out of "PubSub mode", this handler is can be added and removed from a `NIO.ChannelPipeline` as needed.
///
/// When the handler has received a `removeHandler(context:removalToken:)` request, it will remove itself immediately.
public final class RedisPubSubHandler {
    private var state: State = .default

    // each key in the following maps _must_ be prefixed as there can be clashes between patterns and channel names

    /// A map of channel names or patterns and their respective event registration.
    private var subscriptions: [String: Subscription]
    /// A queue of subscribe changes awaiting notification of completion.
    private var pendingSubscribes: PendingSubscriptionChangeQueue
    /// A queue of unsubscribe changes awaiting notification of completion.
    private var pendingUnsubscribes: PendingSubscriptionChangeQueue
    
    private let eventLoop: EventLoop
    
    // we need to be extra careful not to use this context before we know we've initialized
    private var context: ChannelHandlerContext!
    
    /// - Parameters:
    ///     - eventLoop: The event loop the `NIO.Channel` that this handler was added to is bound to.
    ///     - queueCapacity: The initial capacity of queues used for processing subscription changes. The initial value is `3`.
    ///
    ///         Unless you are subscribing and unsubscribing from a large volume of channels or patterns at a single time,
    ///         such as a single SUBSCRIBE call, you do not need to modify this value.
    public init(eventLoop: EventLoop, initialSubscriptionQueueCapacity queueCapacity: Int = 3) {
        self.eventLoop = eventLoop
        self.subscriptions = [:]
        self.pendingSubscribes = [:]
        self.pendingUnsubscribes = [:]
        
        self.pendingSubscribes.reserveCapacity(queueCapacity)
        self.pendingUnsubscribes.reserveCapacity(queueCapacity)
    }
}

// MARK: PubSub Message Handling

extension RedisPubSubHandler {
    private func handleSubscribeMessage(
        withSubscriptionKey subscriptionKey: String,
        reportedSubscriptionCount subscriptionCount: Int,
        keyPrefix: String
    ) {
        let prefixedKey = self.prefixKey(subscriptionKey, with: keyPrefix)
        
        defer { self.pendingSubscribes.removeValue(forKey: prefixedKey)?.succeed(subscriptionCount) }
        
        guard let subscription = self.subscriptions[prefixedKey] else { return }

        subscription.onSubscribe?((subscriptionKey, subscriptionCount))
        subscription.onSubscribe = nil // nil to free memory
        self.subscriptions[prefixedKey] = subscription
        
        subscription.type.gauge.increment()
    }
    
    private func handleUnsubscribeMessage(
        withSubscriptionKey subscriptionKey: String,
        reportedSubscriptionCount subscriptionCount: Int,
        unsubscribeFromAllKey: String,
        keyPrefix: String
    ) {
        let prefixedKey = self.prefixKey(subscriptionKey, with: keyPrefix)
        guard let subscription = self.subscriptions.removeValue(forKey: prefixedKey) else { return }

        subscription.onUnsubscribe?((subscriptionKey, subscriptionCount), .userInitiated)
        subscription.type.gauge.decrement()

        switch self.pendingUnsubscribes.removeValue(forKey: prefixedKey) {
        // we found a specific pattern/channel was being removed, so just fulfill the notification
        case let .some(promise):
            promise.succeed(subscriptionCount)
            
        // if one wasn't found, this means a [p]unsubscribe all was issued
        case .none:
            // and we want to wait for the subscription count to be 0 before we resolve it's notification
            // this count may be from what Redis reports, or the count of subscriptions for this particular type
            guard
                subscriptionCount == 0 || self.subscriptions.count(where: { $0.type == subscription.type }) == 0
            else { return }
            // always report back the count according to Redis, it is the source of truth
            self.pendingUnsubscribes.removeValue(forKey: unsubscribeFromAllKey)?.succeed(subscriptionCount)
        }
    }
    
    private func handleMessage(
        _ message: RESPValue,
        from channel: RedisChannelName,
        withSubscriptionKey subscriptionKey: String,
        keyPrefix: String
    ) {
        guard let subscription = self.subscriptions[self.prefixKey(subscriptionKey, with: keyPrefix)] else { return }
        subscription.onMessage(channel, message)
        RedisMetrics.subscriptionMessagesReceivedCount.increment()
    }
}

// MARK: Subscription Management

extension RedisPubSubHandler {
    /// Registers the provided subscription message receiver to receive messages from the specified subscription target.
    /// - Important: Any previously registered receiver will be replaced and not notified.
    /// - Parameters:
    ///     - target: The channels or patterns that the receiver should receive messages for.
    ///     - receiver: The closure that receives any future pub/sub messages.
    ///     - subscribeHandler: An optional closure to invoke when the subscription first becomes active.
    ///     - unsubscribeHandler: An optional closure to invoke when the subscription becomes inactive.
    /// - Returns: A `NIO.EventLoopFuture` that resolves the number of subscriptions the client has after the subscription has been added.
    public func addSubscription(
        for target: RedisSubscriptionTarget,
        messageReceiver receiver: @escaping RedisSubscriptionMessageReceiver,
        onSubscribe subscribeHandler: RedisSubscribeHandler?,
        onUnsubscribe unsubscribeHandler: RedisUnsubscribeHandler?
    ) -> EventLoopFuture<Int> {
        guard self.eventLoop.inEventLoop else {
            return self.eventLoop.flatSubmit {
                return self.addSubscription(
                    for: target,
                    messageReceiver: receiver,
                    onSubscribe: subscribeHandler,
                    onUnsubscribe: unsubscribeHandler
                )
            }
        }

        switch self.state {
        case .removed: return self.eventLoop.makeFailedFuture(RedisClientError.subscriptionModeRaceCondition)

        case let .error(e): return self.eventLoop.makeFailedFuture(e)
            
        case .default:
            // go through all the target patterns/names and update the map with the new receiver if it's already registered
            // if it was a new registration, not an update, we keep that name to send to Redis
            // we do this so that we save on data transfer bandwidth

            let newSubscriptionTargets = target.values
                .compactMap { (targetKey) -> String? in
                    let subscription = Subscription(
                        type: target.subscriptionType,
                        messageReceiver: receiver,
                        subscribeHandler: subscribeHandler,
                        unsubscribeHandler: unsubscribeHandler
                    )
                    let prefixedKey = self.prefixKey(targetKey, with: target.keyPrefix)
                    guard self.subscriptions.updateValue(subscription, forKey: prefixedKey) == nil else { return nil }
                    return targetKey
                }

            // if there aren't any new actual subscriptions,
            // then we just short circuit and return our local count of subscriptions
            guard !newSubscriptionTargets.isEmpty else {
                return self.eventLoop.makeSucceededFuture(self.subscriptions.count)
            }

            return self.sendSubscriptionChange(
                subscriptionChangeKeyword: target.subscribeKeyword,
                subscriptionTargets: newSubscriptionTargets,
                queue: \.pendingSubscribes,
                keyPrefix: target.keyPrefix
            )
        }
    }

    /// Removes the provided target as a subscription, stopping future messages from being received.
    /// - Parameter target: The channel or pattern that a receiver should be removed for.
    /// - Returns: A `NIO.EventLoopFuture` that resolves the number of subscriptions the client has after the subscription has been removed.
    public func removeSubscription(for target: RedisSubscriptionTarget) -> EventLoopFuture<Int> {
        guard self.eventLoop.inEventLoop else {
            return self.eventLoop.flatSubmit { self.removeSubscription(for: target) }
        }

        // if we're not in our default state,
        // this essentially is a no-op because an error triggers all receivers to be removed
        guard case .default = self.state else { return self.eventLoop.makeSucceededFuture(0) }

        // we send the UNSUBSCRIBE message to Redis,
        // and in the response we handle the actual removal of the receiver closure

        // if there are no channels / patterns specified,
        // then this is a special case of unsubscribing from all patterns / channels
        guard !target.values.isEmpty else {
            return self.unsubscribeAll(for: target)
        }
        
        return self.sendSubscriptionChange(
            subscriptionChangeKeyword: target.unsubscribeKeyword,
            subscriptionTargets: target.values,
            queue: \.pendingUnsubscribes,
            keyPrefix: target.keyPrefix
        )
    }
    
    private func sendSubscriptionChange(
        subscriptionChangeKeyword keyword: String,
        subscriptionTargets targets: [String],
        queue pendingQueue: ReferenceWritableKeyPath<RedisPubSubHandler, PendingSubscriptionChangeQueue>,
        keyPrefix: String
    ) -> EventLoopFuture<Int> {
        self.eventLoop.assertInEventLoop()
        
        var command = [RESPValue(bulk: keyword)]
        command.append(convertingContentsOf: targets)
        
        // the command does not respond in a normal command response fashion of the end count of subscriptions
        // after all of them have been established (or removed)
        //
        // instead, it replies with a subscribe/unsubscribe message for each channel/pattern that was sent
        //
        // so we have to create a top-level future that synchronizes all of the responses
        // where we take the last response from Redis as the count of active subscriptions
        
        // create them
        let pendingSubscriptions: [(String, EventLoopPromise<Int>)] = targets.map {
            return (self.prefixKey($0, with: keyPrefix), self.eventLoop.makePromise())
        }
        // add the subscription change handler to the appropriate queue for each individual subscription target
        pendingSubscriptions.forEach { self[keyPath: pendingQueue].updateValue($1, forKey: $0) }

        // synchronize all of the individual subscription changes
        let subscriptionCountFuture = EventLoopFuture<Int>
            .whenAllComplete(
                pendingSubscriptions.map { $0.1.futureResult },
                on: self.eventLoop
            )
            .flatMapThrowing { (results) -> Int in
                // trust the last success response as the most current count
                guard let latestSubscriptionCount = results
                    .lazy
                    .reversed() // reverse to save time-complexity, as we just need the last (first) successful value
                    .compactMap({ try? $0.get() })
                    .first
                // if we have no success cases, we will still have at least one response that we can
                // rely on the 'get' method to throw the error for us, rather than unwrapping it ourselves
                else { return try results.first!.get() }

                return latestSubscriptionCount
            }
        
        return self.context
            .writeAndFlush(self.wrapOutboundOut(.array(command)))
            .flatMap { return subscriptionCountFuture }
    }

    private func unsubscribeAll(for target: RedisSubscriptionTarget) -> EventLoopFuture<Int> {
        let command = [RESPValue(bulk: target.unsubscribeKeyword)]

        let promise = self.context.eventLoop.makePromise(of: Int.self)
        self.pendingUnsubscribes.updateValue(promise, forKey: target.unsubscribeAllKey)

        return self.context
            .writeAndFlush(self.wrapOutboundOut(.array(command)))
            .flatMap { promise.futureResult }
    }
}

// MARK: ChannelHandler

extension RedisPubSubHandler {
    public func handlerAdded(context: ChannelHandlerContext) {
        self.context = context
    }

    public func handlerRemoved(context: ChannelHandlerContext) {
        self.context = nil // break ref cycles
    }
}

// MARK: RemoveableChannelHandler

extension RedisPubSubHandler: RemovableChannelHandler {
    public func removeHandler(context: ChannelHandlerContext, removalToken: ChannelHandlerContext.RemovalToken) {
        // update our state and leave immediately so we don't get any more subscription requests
        self.state = .removed
        context.leavePipeline(removalToken: removalToken)
        // "close" all subscription handlers
        self.removeAllReceivers()
    }
}

// MARK: ChannelInboundHandler

extension RedisPubSubHandler: ChannelInboundHandler {
    public typealias InboundIn = RESPValue
    public typealias InboundOut = RESPValue
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let value = self.unwrapInboundIn(data)

        // check to see if the value is in the expected PubSub message format
        // if it isn't, then we forward on to the next handler to be treated as a normal command response
        // if it is, we handle it here

        // Redis defines the format as [messageKeyword: String, channelName: String, message: RESPValue]
        // unless the messageType is 'pmessage', in which case it's [messageKeyword, pattern: String, channelName, message]

        // these guards extract some of the basic details of a pubsub message
        guard
            let array = value.array,
            array.count >= 3,
            let channelOrPattern = array[1].string,
            let messageKeyword = array[0].string
        else {
            context.fireChannelRead(data)
            return
        }
        
        // safe because the array is guaranteed from the guard above to have at least 3 elements
        // and it is NOT to be used until we match the PubSub message keyword
        let message = array.last!
        
        // the last check is to match one of the known pubsub message keywords
        // if we have a match, we're definitely in a pubsub message and we should handle it

        switch messageKeyword {
        case "message":
            self.handleMessage(
                message,
                from: .init(channelOrPattern),
                withSubscriptionKey: channelOrPattern,
                keyPrefix: kSubscriptionKeyPrefixChannel
            )

        
        case "pmessage":
            self.handleMessage(
                message,
                from: .init(array[2].string!), // the channel name is stored as the 3rd element in the array in 'pmessage' streams
                withSubscriptionKey: channelOrPattern,
                keyPrefix: kSubscriptionKeyPrefixPattern
            )

        // if the message keyword is for subscribing or unsubscribing,
        // the message is guaranteed to be the count of subscriptions the connection still has
        case "subscribe":
            self.handleSubscribeMessage(
                withSubscriptionKey: channelOrPattern,
                reportedSubscriptionCount: message.int!,
                keyPrefix: kSubscriptionKeyPrefixChannel
            )
            
        case "psubscribe":
            self.handleSubscribeMessage(
                withSubscriptionKey: channelOrPattern,
                reportedSubscriptionCount: message.int!,
                keyPrefix: kSubscriptionKeyPrefixPattern
            )

        case "unsubscribe":
            self.handleUnsubscribeMessage(
                withSubscriptionKey: channelOrPattern,
                reportedSubscriptionCount: message.int!,
                unsubscribeFromAllKey: kUnsubscribeAllChannelsKey,
                keyPrefix: kSubscriptionKeyPrefixChannel
            )
            
        case "punsubscribe":
            self.handleUnsubscribeMessage(
                withSubscriptionKey: channelOrPattern,
                reportedSubscriptionCount: message.int!,
                unsubscribeFromAllKey: kUnsubscribeAllPatternsKey,
                keyPrefix: kSubscriptionKeyPrefixPattern
            )
            
        // if we don't have a match, fire a channel read to forward to the next handler
        default: context.fireChannelRead(data)
        }
    }
    
    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        self.removeAllReceivers(because: error)
        context.fireErrorCaught(error)
    }
    
    public func channelInactive(context: ChannelHandlerContext) {
        self.removeAllReceivers(because: RedisClientError.connectionClosed)
        context.fireChannelInactive()
    }
    
    private func removeAllReceivers(because error: Error? = nil) {
        error.map { self.state = .error($0) }
        
        let receivers = self.subscriptions
        self.subscriptions.removeAll()
        receivers.forEach {
            let source: RedisUnsubscribeEventSource = error.map { .clientError($0) } ?? .userInitiated
            $0.value.onUnsubscribe?(($0.key, 0), source)
            $0.value.type.gauge.decrement()
        }
    }
}

// MARK: ChannelOutboundHandler

extension RedisPubSubHandler: ChannelOutboundHandler {
    public typealias OutboundIn = RESPValue
    public typealias OutboundOut = RESPValue
    
    // the pub/sub handler is a transparent outbound handler
    // we only conform to the protocol so we're appropriately placed in the pipeline
    // to bypass the command handler for pub/sub subscription changes
}

// MARK: Private Types

// keys used for the pendingUnsubscribes
private let kUnsubscribeAllChannelsKey = "__RS_ALL_CHS"
private let kUnsubscribeAllPatternsKey = "__RS_ALL_PNS"

fileprivate enum SubscriptionType {
    case channel, pattern
    
    var gauge: RedisMetrics.IncrementalGauge {
        switch self {
        case .channel: return RedisMetrics.activeChannelSubscriptions
        case .pattern: return RedisMetrics.activePatternSubscriptions
        }
    }
}

extension RedisPubSubHandler {
    private typealias PendingSubscriptionChangeQueue = [String: EventLoopPromise<Int>]

    fileprivate final class Subscription {
        let type: SubscriptionType
        let onMessage: RedisSubscriptionMessageReceiver
        var onSubscribe: RedisSubscribeHandler? // will be set to nil after first call
        let onUnsubscribe: RedisUnsubscribeHandler?
        
        init(
            type: SubscriptionType,
            messageReceiver: @escaping RedisSubscriptionMessageReceiver,
            subscribeHandler: RedisSubscribeHandler?,
            unsubscribeHandler: RedisUnsubscribeHandler?
        ) {
            self.type = type
            self.onMessage = messageReceiver
            self.onSubscribe = subscribeHandler
            self.onUnsubscribe = unsubscribeHandler
        }
    }

    private enum State {
        case `default`, removed, error(Error)
    }
}

// MARK: Subscription Management Helpers

private let kSubscriptionKeyPrefixChannel = "__RS_CS"
private let kSubscriptionKeyPrefixPattern = "__RS_PS"

extension RedisPubSubHandler {
    private func prefixKey(_ key: String, with prefix: String) -> String { "\(prefix)_\(key)" }
}

extension RedisSubscriptionTarget {
    fileprivate var unsubscribeAllKey: String {
        switch self {
        case .channels: return kUnsubscribeAllChannelsKey
        case .patterns: return kUnsubscribeAllPatternsKey
        }
    }

    fileprivate var keyPrefix: String {
        switch self {
        case .channels: return kSubscriptionKeyPrefixChannel
        case .patterns: return kSubscriptionKeyPrefixPattern
        }
    }

    fileprivate var subscriptionType: SubscriptionType {
        switch self {
        case .channels: return .channel
        case .patterns: return .pattern
        }
    }
    
    fileprivate var subscribeKeyword: String {
        switch self {
        case .channels: return "SUBSCRIBE"
        case .patterns: return "PSUBSCRIBE"
        }
    }
    fileprivate var unsubscribeKeyword: String {
        switch self {
        case .channels: return "UNSUBSCRIBE"
        case .patterns: return "PUNSUBSCRIBE"
        }
    }
}

extension Dictionary where Key == String, Value == RedisPubSubHandler.Subscription {
    func count(where isIncluded: (Value) -> Bool) -> Int {
        self.reduce(into: 0) {
            guard isIncluded($1.value) else { return }
            $0 += 1
        }
    }
}
