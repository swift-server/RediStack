import Foundation
import Logging

/// An object that provides a mechanism to "pipeline" multiple Redis commands in sequence,
/// providing an aggregate response of all the Redis responses for each individual command.
///
///     let results = connection.makePipeline()
///         .enqueue { $0.set("my_key", "3") }
///         .enqueue { $0.send(command: "INCR", with: ["my_key"]) }
///         .execute()
///     // results == Future<[RESPValue]>
///     // results[0].string == Optional("OK")
///     // results[1].int == Optional(4)
///
/// See [https://redis.io/topics/pipelining#redis-pipelining](https://redis.io/topics/pipelining#redis-pipelining)
/// - Important: The larger the pipeline queue, the more memory both NIORedis and Redis will use.
public protocol RedisPipeline {
    /// The number of commands in the pipeline.
    var count: Int { get }

    /// Queues an operation executed with the provided `RedisClient` that will be executed in sequence when
    /// `execute()` is invoked.
    ///
    ///     let pipeline = connection.makePipeline()
    ///         .enqueue { $0.set("my_key", "3") }
    ///         .enqueue { $0.send(command: "INCR", with: ["my_key"]) }
    ///
    /// See `RedisClient`.
    /// - Parameter operation: The operation specified with `RedisClient` provided.
    /// - Returns: A self-reference for chaining commands.
    @discardableResult
    func enqueue<T>(operation: (RedisClient) -> EventLoopFuture<T>) -> RedisPipeline

    /// Flushes the queue, sending all of the commands to Redis.
    /// - Returns: An `EventLoopFuture` that resolves the `RESPValue` responses, in the same order as the command queue.
    func execute() -> EventLoopFuture<[RESPValue]>
}

public final class NIORedisPipeline {
    private var logger: Logger
    /// The channel being used to send commands with.
    private let channel: Channel

    /// The queue of response handlers that have been queued.
    private var queuedCommandResults: [EventLoopFuture<RESPValue>]

    /// Creates a new pipeline queue that will write to the channel provided.
    /// - Parameter channel: The `Channel` to write to.
    public init(channel: Channel, logger: Logger = Logger(label: "NIORedis.Pipeline")) {
        self.channel = channel
        self.logger = logger
        self.queuedCommandResults = []

        self.logger[metadataKey: "RedisPipeline"] = "\(UUID())"
        self.logger.debug("Pipeline created.")
    }
}

extension NIORedisPipeline: RedisPipeline {
    /// See `RedisPipeline.count`.
    public var count: Int {
        return queuedCommandResults.count
    }

    /// See `RedisPipeline.enqueue(operation:)`.
    @discardableResult
    public func enqueue<T>(operation: (RedisClient) -> EventLoopFuture<T>) -> RedisPipeline {
        // We are passing ourselves in as the executor instance,
        // and our implementation of `RedisCommandExecutor.send(command:with:) handles the actual queueing.
        _ = operation(self)
        logger.debug("Command queued. Pipeline size: \(count)")
        return self
    }

    /// See `RedisPipeline.execute()`.
    /// - Important: If any of the commands fail, the remaining commands will not execute and the `EventLoopFuture` will fail.
    public func execute() -> EventLoopFuture<[RESPValue]> {
        let response = EventLoopFuture<[RESPValue]>.reduce(
            into: [],
            queuedCommandResults,
            on: channel.eventLoop,
            { (results, response) in results.append(response) }
        )

        response.whenComplete { result in
            self.queuedCommandResults = []

            switch result {
            case .failure(let error): self.logger.error("\(error)")
            case .success: self.logger.debug("Pipeline executed.")
            }
        }

        channel.flush()

        return response
    }
}

extension NIORedisPipeline: RedisClient {
    /// See `RedisCommandExecutor.eventLoop`.
    public var eventLoop: EventLoop { return self.channel.eventLoop }

    /// Sends the command and arguments to a buffer to later be flushed when `execute()` is invoked.
    /// - Note: When working with a `NIORedisPipeline` instance directly, it is preferred to use the
    ///     `RedisPipeline.enqueue(operation:)` method instead of `send(command:with:)`.
    public func send(command: String, with arguments: [RESPValueConvertible] = []) -> EventLoopFuture<RESPValue> {
        let args = arguments.map { $0.convertedToRESPValue() }

        let promise = channel.eventLoop.makePromise(of: RESPValue.self)
        let context = RedisCommandContext(
            command: .array([RESPValue(bulk: command)] + args),
            promise: promise
        )

        queuedCommandResults.append(promise.futureResult)

        logger.debug("Enqueuing command \"\(command)\" with \(arguments) encoded as \(args)")

        _ = channel.write(context)

        return promise.futureResult
    }
}
