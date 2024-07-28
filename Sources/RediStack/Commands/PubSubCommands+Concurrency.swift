//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2020 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOCore

// MARK: Publish

extension RedisClient {
    /// Publishes the provided message to a specific Redis channel.
    ///
    /// See [PUBLISH](https://redis.io/commands/publish)
    /// - Parameters:
    ///     - message: The "message" value to publish on the channel.
    ///     - channel: The name of the channel to publish the message to.
    /// - Returns: The number of subscribed clients that received the message.
    @inlinable
    @discardableResult
    public func publish<Message: RESPValueConvertible>(
        _ message: Message,
        to channel: RedisChannelName
    ) -> EventLoopFuture<Int> {
        let args: [RESPValue] = [
            .init(from: channel),
            message.convertedToRESPValue()
        ]
        return self.send(command: "PUBLISH", with: args)
            .tryConverting()
    }
}

// MARK: PubSub Sub-commands

extension RedisClient {
    /// Resolves a list of all the channels that have at least 1 (non-pattern) subscriber.
    ///
    /// See [PUBSUB CHANNELS](https://redis.io/commands/pubsub#pubsub-channels-pattern)
    /// - Note: If no `match` pattern is provided, all active channels will be returned.
    /// - Parameter match: An optional pattern of channel names to filter for.
    /// - Returns: A list of all active channel names.
    public func activeChannels(matching match: String? = nil) -> EventLoopFuture<[RedisChannelName]> {
        var args: [RESPValue] = [.init(bulk: "CHANNELS")]
        
        if let m = match { args.append(.init(bulk: m)) }
        
        return self.send(command: "PUBSUB", with: args)
            .tryConverting()
    }
    
    /// Resolves the total count of active subscriptions to channels that were made using patterns.
    ///
    /// See [PUBSUB NUMPAT](https://redis.io/commands/pubsub#codepubsub-numpatcode)
    /// - Returns: The total count of subscriptions made through patterns.
    public func patternSubscriberCount() -> EventLoopFuture<Int> {
        let args: [RESPValue] = [.init(bulk: "NUMPAT")]
        return self.send(command: "PUBSUB", with: args)
            .tryConverting()
    }
    
    /// Resolves a count of (non-pattern) subscribers for each given channel.
    ///
    /// See [PUBSUB NUMSUB](https://redis.io/commands/pubsub#codepubsub-numsub-channel-1--channel-ncode)
    /// - Parameter channels: A list of channel names to collect the subscriber counts for.
    /// - Returns: A mapping of channel names and their (non-pattern) subscriber count.
    public func subscriberCount(forChannels channels: [RedisChannelName]) -> EventLoopFuture<[RedisChannelName: Int]> {
        guard channels.count > 0 else { return self.eventLoop.makeSucceededFuture([:]) }
        
        var args: [RESPValue] = [.init(bulk: "NUMSUB")]
        args.append(convertingContentsOf: channels)
        
        return self.send(command: "PUBSUB", with: args)
            .tryConverting(to: [RESPValue].self)
            .flatMapThrowing { response in
                assert(response.count == channels.count * 2, "Unexpected response size!")
                
                // Redis guarantees that the response format is [channel1Name, channel1Count, channel2Name, ...]
                // with the order of channels matching the order sent in the request
                return try channels
                    .enumerated()
                    .reduce(into: [:]) { (result, next) in
                        let responseOffset = next.offset * 2
                        assert(next.element.rawValue == response[responseOffset].string, "Unexpected value in current index!")
                        
                        guard let count = response[responseOffset + 1].int else {
                            throw RedisClientError.assertionFailure(
                                message: "Unexpected value at position \(responseOffset + 1) in \(response)"
                            )
                        }
                        result[next.element] = count
                    }
            }
    }
}
