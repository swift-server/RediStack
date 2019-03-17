import Foundation

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

    /// Queues an operation executed with the provided `RedisCommandExecutor` that will be executed in sequence when
    /// `execute()` is invoked.
    ///
    ///     let pipeline = connection.makePipeline()
    ///         .enqueue { $0.set("my_key", "3") }
    ///         .enqueue { $0.send(command: "INCR", with: ["my_key"]) }
    ///
    /// See `RedisCommandExecutor`.
    /// - Parameter operation: The operation specified with `RedisCommandExecutor` provided.
    /// - Returns: A self-reference for chaining commands.
    @discardableResult
    func enqueue<T>(operation: (RedisCommandExecutor) -> EventLoopFuture<T>) -> RedisPipeline

    /// Flushes the queue, sending all of the commands to Redis.
    /// - Returns: An `EventLoopFuture` that resolves the `RESPValue` responses, in the same order as the command queue.
    func execute() -> EventLoopFuture<[RESPValue]>
}

public final class NIORedisPipeline {
    /// The channel being used to send commands with.
    private let channel: Channel

    /// The queue of response handlers that have been queued.
    private var queuedCommandResults: [EventLoopFuture<RESPValue>]

    /// Creates a new pipeline queue that will write to the channel provided.
    /// - Parameter channel: The `Channel` to write to.
    public init(channel: Channel) {
        self.channel = channel
        self.queuedCommandResults = []
    }
}

extension NIORedisPipeline: RedisPipeline {
    /// See `RedisPipeline.count`.
    public var count: Int {
        return queuedCommandResults.count
    }

    /// See `RedisPipeline.enqueue(operation:)`.
    @discardableResult
    public func enqueue<T>(operation: (RedisCommandExecutor) -> EventLoopFuture<T>) -> RedisPipeline {
        // We are passing ourselves in as the executor instance,
        // and our implementation of `RedisCommandExecutor.send(command:with:) handles the actual queueing.
        _ = operation(self)
        return self
    }

    /// See `RedisPipeline.execute()`.
    /// - Important: If any of the commands fail, the remaining commands will not execute and the `EventLoopFuture` will fail.
    public func execute() -> EventLoopFuture<[RESPValue]> {
        channel.flush()

        let response = EventLoopFuture<[RESPValue]>.reduce(
            into: [],
            queuedCommandResults,
            on: channel.eventLoop,
            { (results, response) in results.append(response) }
        )

        response.whenComplete { _ in self.queuedCommandResults = [] }

        return response
    }
}

extension NIORedisPipeline: RedisCommandExecutor {
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

        _ = channel.write(context)

        return promise.futureResult
    }
}
