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

// MARK: PubSub

extension RedisCommand {
    /// See [PUBLISH](https://redis.io/commands/publish)
    /// - Parameters:
    ///     - message: The "message" value to publish on the channel.
    ///     - channel: The name of the channel to publish the message to.
    @inlinable
    public static func publish<Message: RESPValueConvertible>(
        _ message: Message,
        to channel: RedisChannelName
    ) -> RedisCommand<Int> {
        let args: [RESPValue] = [
            .init(from: channel),
            message.convertedToRESPValue()
        ]
        return .init(keyword: "PUBLISH", arguments: args)
    }

    /// [PUBSUB CHANNELS](https://redis.io/commands/pubsub#pubsub-channels-pattern)
    /// - Invariant: If no `match` pattern is provided, all active channels will be returned.
    /// - Parameter match: An optional pattern of channel names to filter for.
    public static func pubsubChannels(matching match: String? = nil) -> RedisCommand<[RedisChannelName]> {
        var args: [RESPValue] = [.init(bulk: "CHANNELS")]
        if let match = match {
            args.append(.init(bulk: match))
        }
        return .init(keyword: "PUBSUB", arguments: args)
    }

    /// [PUBSUB NUMPAT](https://redis.io/commands/pubsub#codepubsub-numpatcode)
    public static func pubsubNumpat() -> RedisCommand<Int> {
        return .init(keyword: "PUBSUB", arguments: [.init(bulk: "NUMPAT")])
    }

    /// [PUBSUB NUMSUB](https://redis.io/commands/pubsub#codepubsub-numsub-channel-1--channel-ncode)
    /// - Parameter channels: A list of channel names to collect the subscriber counts for.
    public static func pubsubNumsub(forChannels channels: [RedisChannelName]) -> RedisCommand<[RedisChannelName: Int]> {
        var args: [RESPValue] = [.init(bulk: "NUMSUB")]
        args.append(convertingContentsOf: channels)
        return .init(keyword: "PUBSUB", arguments: args) {
            let response = try $0.map(to: [RESPValue].self)
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

// MARK: -

extension RedisClient {
    /// Publishes the provided message to a specific Redis channel.
    ///
    /// See ``RedisCommand/publish(_:to:)``
    /// - Parameters:
    ///     - message: The "message" value to publish on the channel.
    ///     - channel: The name of the channel to publish the message to.
    ///     - eventLoop: An optional event loop to hop to for any further chaining on the returned event loop future.
    ///     - logger: An optional logger instance to use for logs generated from this command.
    /// - Returns: The number of subscribed clients that received the message.
    @inlinable
    @discardableResult
    public func publish<Message: RESPValueConvertible>(
        _ message: Message,
        to channel: RedisChannelName,
        eventLoop: EventLoop? = nil,
        logger: Logger? = nil
    ) -> EventLoopFuture<Int> {
        return self.send(.publish(message, to: channel), eventLoop: eventLoop, logger: logger)
    }
}
