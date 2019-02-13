import Foundation

/// An object that provides a mechanism to "pipeline" multiple Redis commands in sequence,
/// providing an aggregate response of all the Redis responses for each individual command.
///
///     let results = connection.makePipeline()
///         .enqueue(command: "SET", arguments: ["my_key", 3])
///         .enqueue(command: "INCR", arguments: ["my_key"])
///         .execute()
///     // results == Future<[RESPValue]>
///     // results[0].string == Optional("OK")
///     // results[1].int == Optional(4)
///
/// See https://redis.io/topics/pipelining#redis-pipelining
/// - Important: The larger the pipeline queue, the more memory both NIORedis and Redis will use.
public final class RedisPipeline {
    /// The number of commands in the pipeline.
    public var count: Int {
        return queuedCommandResults.count
    }

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

    /// Queues the provided command and arguments to be executed when `execute()` is invoked.
    /// - Parameters:
    ///     - command: The command to execute. See https://redis.io/commands
    ///     - arguments: The arguments, if any, to send with the command.
    /// - Returns: A self-reference for chaining commands.
    @discardableResult
    public func enqueue(command: String, arguments: [RESPValueConvertible] = []) throws -> RedisPipeline {
        let args = arguments.map { $0.convertedToRESPValue() }

        let promise = channel.eventLoop.makePromise(of: RESPValue.self)
        let context = RedisCommandContext(
            command: .array([RESPValue(bulk: command)] + args),
            promise: promise
        )

        queuedCommandResults.append(promise.futureResult)

        _ = channel.write(context)

        return self
    }

    /// Flushes the queue, sending all of the commands to Redis.
    /// - Important: If any of the commands fail, the remaining commands will not execute and the `EventLoopFuture` will fail.
    /// - Returns: An `EventLoopFuture` that resolves the `RESPValue` responses, in the same order as the command queue.
    public func execute() -> EventLoopFuture<[RESPValue]> {
        channel.flush()

        return EventLoopFuture<[RESPValue]>.reduce(
            into: [],
            queuedCommandResults,
            on: channel.eventLoop,
            { (results, response) in results.append(response) }
        )
    }
}
