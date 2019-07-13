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

import NIO

// MARK: Publish

extension RedisClient {
    /// Publishes a message to a specific Redis channel.
    ///
    /// See [https://redis.io/commands/publish](https://redis.io/commands/publish)
    /// - Parameters:
    ///     - message: The message content to publish on the channel.
    ///     - channel: The name of the channel to publish to.
    /// - Returns: A `NIO.EventLoopFuture` that resolves the number of subscribed clients that received the message.
    @inlinable
    @discardableResult
    public func publish<Content: RESPValueConvertible>(
        _ message: Content,
        toChannel channel: String
    ) -> EventLoopFuture<Int> {
        let args: [RESPValue] = [
            message.convertedToRESPValue(),
            .init(bulk: channel)
        ]
        return send(command: "PUBLISH", with: args)
            .convertFromRESPValue()
    }
}

// MARK: PubSub Sub-commands

extension RedisClient {
    /// Lists all the channels that have at least 1 subscriber.
    /// - Note: If no `match` pattern is provided, all active channels will be returned.
    ///
    /// See [https://redis.io/commands/pubsub#pubsub-channels-pattern](https://redis.io/commands/pubsub#pubsub-channels-pattern)
    /// - Parameter match: An optional pattern of channel names to filter for.
    /// - Returns: A `NIO.EventLoopFuture` resolving a list of active channel names.
    @inlinable
    public func activeChannels(matching match: String? = nil) -> EventLoopFuture<[String]> {
        var args: [RESPValue] = [.init(bulk: "CHANNELS")]
        
        if let m = match { args.append(.init(bulk: m)) }
        
        return send(command: "PUBSUB", with: args)
            .convertFromRESPValue()
    }
    
    /// Resolves the total count of active subscriptions to channels that were made using patterns.
    ///
    /// See [https://redis.io/commands/pubsub#codepubsub-numpatcode](https://redis.io/commands/pubsub#codepubsub-numpatcode)
    /// - Returns: A `NIO.EventLoopFuture` that resolves the total count of subscriptions made through patterns.
    @inlinable
    public func patternSubscriberCount() -> EventLoopFuture<Int> {
        let args: [RESPValue] = [.init(bulk: "NUMPAT")]
        return send(command: "PUBSUB", with: args)
            .convertFromRESPValue()
    }
    
    /// Resolves a count of subscribers for each given channel.
    /// - Important: This command excludes clients that are subscribed through pattern matching.
    ///
    /// See [https://redis.io/commands/pubsub#codepubsub-numsub-channel-1--channel-ncode](https://redis.io/commands/pubsub#codepubsub-numsub-channel-1--channel-ncode)
    /// - Parameter channels: A list of channel names to resolve the subscriber counts for.
    /// - Returns: A `NIO.EventLoopFuture` resolving a map of channel names and their subscriber count.
    @inlinable
    public func subscriberCount(forChannels channels: [String]) -> EventLoopFuture<[String: Int]> {
        guard channels.count > 0 else { return self.eventLoop.makeSucceededFuture([:]) }
        
        var args: [RESPValue] = [.init(bulk: "NUMSUB")]
        args.append(convertingContentsOf: channels)
        
        return send(command: "PUBSUB", with: args)
            .convertFromRESPValue(to: [RESPValue].self)
            .flatMapThrowing { response in
                assert(response.count == channels.count * 2, "Unexpected response size!")
                
                var results: [String: Int] = [:]
                results.reserveCapacity(channels.count)
                
                // Redis guarantees that the response format is [channel, count, channel, ...]
                // with the order of channels matching the order sent in the request
                for (index, channel) in channels.enumerated() {
                    assert(channel == response[index].string, "Unexpected value in current index!")
                    
                    guard let count = response[index + 1].int else {
                        throw RedisClientError.assertionFailure(message: "Unexpected value at position \(index + 1) in \(response)")
                    }
                    results[channel] = count
                }
                
                return results
            }
    }
}
