//===----------------------------------------------------------------------===//
//
// This source file is part of the RedisNIO open source project
//
// Copyright (c) 2019 RedisNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RedisNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct Foundation.UUID
import struct Dispatch.DispatchTime
import Logging
import Metrics
import NIO
import NIOConcurrencyHelpers

/// An object capable of sending commands and receiving responses.
///
///     let client = ...
///     let result = client.send(command: "GET", arguments: ["my_key"])
///     // result == EventLoopFuture<RESPValue>
///
/// See [https://redis.io/commands](https://redis.io/commands)
public protocol RedisClient {
    /// The `EventLoop` that this client operates on.
    var eventLoop: EventLoop { get }

    /// Sends the desired command with the specified arguments.
    /// - Parameters:
    ///     - command: The command to execute.
    ///     - arguments: The arguments, if any, to be sent with the command.
    /// - Returns: An `EventLoopFuture` that will resolve with the Redis command response.
    func send(command: String, with arguments: [RESPValueConvertible]) -> EventLoopFuture<RESPValue>
}

extension RedisClient {
    /// Sends the desired command without arguments.
    /// - Parameter command: The command keyword to execute.
    /// - Returns: An `EventLoopFuture` that will resolve with the Redis command response.
    public func send(command: String) -> EventLoopFuture<RESPValue> {
        return self.send(command: command, with: [])
    }
}

private let loggingKeyID = "RedisConnection"

/// A `RedisClient` implementation that represents an individual connection
/// to a Redis database instance.
///
/// `RedisConnection` comes with logging by default.
///
/// See `RedisClient`
public final class RedisConnection: RedisClient {
    private enum ConnectionState {
        case open
        case closed
    }

    /// See `RedisClient.eventLoop`
    public var eventLoop: EventLoop { return channel.eventLoop }
    /// Is the client still connected to Redis?
    public var isConnected: Bool { return state != .closed }
    /// Controls the timing behavior of sending commands over this connection. The default is `true`.
    ///
    /// When set to `false`, the host will "queue" commands and determine when to send all at once,
    /// while `true` will force each command to be sent as soon as they are "queued".
    /// - Note: Setting this to `true` will trigger all "queued" commands to be sent.
    public var sendCommandsImmediately: Bool {
        get { return autoflush.load() }
        set(newValue) {
            if newValue { channel.flush() }
            autoflush.store(newValue)
        }
    }

    let channel: Channel
    private var logger: Logger

    private let autoflush = Atomic<Bool>(value: true)
    private let _stateLock = Lock()
    private var _state: ConnectionState
    private var state: ConnectionState {
        get { return _stateLock.withLock { self._state } }
        set(newValue) { _stateLock.withLockVoid { self._state = newValue } }
    }

    deinit {
        if isConnected {
            assertionFailure("close() was not called before deinit!")
            logger.warning("RedisConnection did not properly shutdown before deinit!")
        }
    }

    /// Creates a new connection on the provided `Channel`.
    /// - Important: Call `close()` before deinitializing to properly cleanup resources.
    /// - Note: This connection will take ownership of the channel.
    /// - Parameters:
    ///     - channel: The `Channel` to read and write from.
    ///     - logger: The `Logger` instance to use for all logging purposes.
    public init(channel: Channel, logger: Logger = Logger(label: "RedisNIO.RedisConnection")) {
        self.channel = channel
        self.logger = logger

        self.logger[metadataKey: loggingKeyID] = "\(UUID())"
        self.logger.debug("Connection created.")
        self._state = .open
        RedisMetrics.activeConnectionCount += 1
        RedisMetrics.totalConnectionCount.increment()
    }

    /// Sends a `QUIT` command, then closes the `Channel` this instance was initialized with.
    ///
    /// See [https://redis.io/commands/quit](https://redis.io/commands/quit)
    /// - Returns: An `EventLoopFuture` that resolves when the connection has been closed.
    @discardableResult
    public func close() -> EventLoopFuture<Void> {
        guard isConnected else {
            logger.notice("Connection received more than one close() request.")
            return channel.eventLoop.makeSucceededFuture(())
        }

        let result = send(command: "QUIT")
            .flatMap { _ in
                let promise = self.channel.eventLoop.makePromise(of: Void.self)
                self.channel.close(promise: promise)
                return promise.futureResult
            }
            .map {
                self.logger.debug("Connection closed.")
                RedisMetrics.activeConnectionCount -= 1
            }
            .recover {
                self.logger.error("Encountered error during close(): \($0)")
                self.state = .open
            }

        // setting it to closed now prevents multiple close() chains, but doesn't stop the QUIT command
        // if the connection wasn't closed, it's reset in the callback chain
        state = .closed

        return result
    }

    /// Sends commands to the Redis instance this connection is tied to.
    ///
    /// See `RedisClient.send(command:with:)`
    ///
    /// - Note: The timing of when commands are actually sent to Redis are controlled by
    ///     the `sendCommandsImmediately` property.
    public func send(
        command: String,
        with arguments: [RESPValueConvertible]
    ) -> EventLoopFuture<RESPValue> {
        guard isConnected else {
            logger.error("\(RedisNIOError.connectionClosed.localizedDescription)")
            return channel.eventLoop.makeFailedFuture(RedisNIOError.connectionClosed)
        }

        let args = arguments.map { $0.convertedToRESPValue() }

        let promise = channel.eventLoop.makePromise(of: RESPValue.self)
        let context = RedisCommandContext(
            command: .array([RESPValue(bulk: command)] + args),
            promise: promise
        )

        let startTime = DispatchTime.now().uptimeNanoseconds
        promise.futureResult.whenComplete { result in
            let duration = DispatchTime.now().uptimeNanoseconds - startTime
            RedisMetrics.commandRoundTripTime.recordNanoseconds(duration)
            guard case let .failure(error) = result else { return }
            self.logger.error("\(error.localizedDescription)")
        }
        logger.debug("Sending command \"\(command)\" with \(arguments) encoded as \(args)")

        guard sendCommandsImmediately else {
            return channel.write(context).flatMap { promise.futureResult }
        }
        return channel.writeAndFlush(context).flatMap { promise.futureResult }
    }
}
