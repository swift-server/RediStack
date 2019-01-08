import Foundation
import NIO

/// An object that provides a mechanism to "pipeline" multiple Redis commands in sequence, providing an aggregate response
/// of all the Redis responses for each individual command.
///
///     let results = connection.makePipeline()
///         .enqueue(command: "SET", arguments: ["my_key", 3])
///         .enqueue(command: "INCR", arguments: ["my_key"])
///         .execute()
///     // results == Future<[RedisData]>
///     // results[0].string == Optional("OK")
///     // results[1].int == Optional(4)
/// - Important: The larger the pipeline queue, the more memory both NIORedis and Redis will use.
/// See https://redis.io/topics/pipelining#redis-pipelining
public final class NIORedisPipeline {
    /// The client to execute the commands on.
    private let connection: NIORedisConnection
    private let encoder: RedisDataEncoder = .init()

    /// The queue of complete, encoded commands to execute.
    private var queue: [RedisData]
    private var messageCount: Int

    /// Creates a new pipeline queue using the provided `NIORedisConnection`.
    /// - Parameter using: The connection to execute the commands on.
    public init(using connection: NIORedisConnection) {
        self.connection = connection
        self.queue = []
        self.messageCount = 0
    }

    /// Queues the provided command and arguments to be executed when `execute()` is invoked.
    /// - Parameters:
    ///     - command: The command to execute. See https://redis.io/commands
    ///     - arguments: The arguments, if any, to send with the command.
    /// - Returns: A self-reference to this `NIORedisPipeline` instance for chaining commands.
    @discardableResult
    public func enqueue(command: String, arguments: [RedisDataConvertible] = []) throws -> NIORedisPipeline {
        let args = try arguments.map { try $0.convertToRedisData() }

        queue.append(.array([RedisData(bulk: command)] + args))

        return self
    }

    /// Flushes the queue, sending all of the commands to Redis in the same order as they were enqueued.
    /// - Important: If any of the commands fail, the remaining commands will not execute and the `EventLoopFuture` will fail.
    /// - Returns: A `EventLoopFuture` that resolves the `RedisData` responses, in the same order as the command queue.
    public func execute() -> EventLoopFuture<[RedisData]> {
        let promise = connection.eventLoop.makePromise(of: [RedisData].self)

        var results = [RedisData]()
        var iterator = queue.makeIterator()

        // recursive internal method for chaining each request and
        // attaching callbacks for failing or ultimately succeeding
        func handle(_ command: RedisData) {
            let future = connection._send(command)
            future.whenSuccess { response in
                switch response {
                case let .error(error): promise.fail(error: error)
                default:
                    results.append(response)

                    if let next = iterator.next() {
                        handle(next)
                    } else {
                        promise.succeed(result: results)
                    }
                }
            }
            future.whenFailure { promise.fail(error: $0) }
        }

        if let first = iterator.next() {
            handle(first)
        } else {
            promise.succeed(result: [])
        }

        promise.futureResult.whenComplete { self.queue = [] }

        return promise.futureResult
    }
}
