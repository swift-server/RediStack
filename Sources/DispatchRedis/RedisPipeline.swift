import Foundation
import NIORedis

/// An object that provides a mechanism to "pipeline" multiple Redis commands in sequence, providing an aggregate response
/// of all the Redis responses for each individual command.
///
///     connection.makePipeline()
///         .enqueue(command: "SET", arguments: ["my_key", 3])
///         .enqueue(command: "INCR", arguments: ["my_key"])
///         .execute { results in
///             // results[0].string == Optional("OK")
///             // results[1].int == Optional(4)
///         }
/// - Important: The larger the pipeline queue, the more memory both the Redis driver and Redis server will use.
/// See https://redis.io/topics/pipelining#redis-pipelining
public final class RedisPipeline {
    private let _driverPipeline: NIORedis.RedisPipeline
    private let queue: DispatchQueue

    /// Creates a new pipeline queue using the provided `RedisConnection`, executing callbacks on the provided `DispatchQueue`.
    /// - Parameters:
    ///     - using: The connection to execute the commands on.
    ///     - callbackQueue: The queue to execute all callbacks on.
    public init(connection: RedisConnection, callbackQueue: DispatchQueue) {
        self._driverPipeline = NIORedis.RedisPipeline(channel: connection._driverConnection.channel)
        self.queue = callbackQueue
    }

    /// Queues the provided command and arguments to be executed when `execute()` is invoked.
    /// - Parameters:
    ///     - command: The command to execute. See https://redis.io/commands
    ///     - arguments: The arguments, if any, to send with the command.
    /// - Returns: A self-reference to this `RedisPipeline` instance for chaining commands.
    @discardableResult
    public func enqueue(command: String, arguments: [RESPValueConvertible] = []) throws -> RedisPipeline {
        try _driverPipeline.enqueue(command: command, arguments: arguments)
        return self
    }

    /// Flushes the queue, sending all of the commands to Redis in the same order as they were enqueued.
    /// - Important: If any of the commands fail, the remaining commands will not execute and the callback will receive a failure.
    /// - Parameter callback: The callback to receive the results of the pipeline of commands, or an error if thrown.
    public func execute(_ callback: @escaping (Result<[RESPValue], Error>) -> Void) {
        _driverPipeline.execute()
            .map { results in
                self.queue.async { callback(.success(results)) }
            }
            .whenFailure { error in
                self.queue.async { callback(.failure(error)) }
            }
    }
}
