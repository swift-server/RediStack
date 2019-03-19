import NIO
import NIOConcurrencyHelpers

/// A connection to a Redis database instance, with the ability to send and receive commands.
///
///     let result = connection.send(command: "GET", arguments: ["my_key"]
///     // result == EventLoopFuture<RESPValue>
///
/// See [https://redis.io/commands](https://redis.io/commands)
public final class RedisConnection {
    /// The `Channel` this connection is associated with.
    public let channel: Channel

    /// Has the connection been closed?
    public var isClosed: Bool { return _isClosed.load() }
    private var _isClosed = Atomic<Bool>(value: false)

    deinit { assert(_isClosed.load(), "Redis connection was not properly shut down!") }

    /// Creates a new connection on the provided channel.
    /// - Note: This connection will take ownership of the `Channel` object.
    /// - Important: Call `close()` before deinitializing to properly cleanup resources.
    public init(channel: Channel) {
        self.channel = channel
    }

    /// Closes the connection to Redis.
    /// - Returns: An `EventLoopFuture` that resolves when the connection has been closed.
    @discardableResult
    public func close() -> EventLoopFuture<Void> {
        guard !_isClosed.exchange(with: true) else { return channel.eventLoop.makeSucceededFuture(()) }

        return send(command: "QUIT")
            .flatMap { _ in
                let promise = self.channel.eventLoop.makePromise(of: Void.self)
                self.channel.close(promise: promise)
                return promise.futureResult
            }
    }

    /// Sends the desired command with the specified arguments.
    /// - Parameters:
    ///     - command: The command to execute.
    ///     - arguments: The arguments to be sent with the command.
    /// - Returns: An `EventLoopFuture` that will resolve with the Redis command response.
    public func send(command: String, with arguments: [RESPValueConvertible] = []) -> EventLoopFuture<RESPValue> {
        let args = arguments.map { $0.convertedToRESPValue() }
        return self.command(command, arguments: args)
    }

    /// Invokes a command against Redis with the provided arguments.
    /// - Important: Arguments should be stored as `.bulkString`.
    /// - Parameters:
    ///     - command: The command to execute.
    ///     - arguments: The arguments to be sent with the command.
    /// - Returns: An `EventLoopFuture` that will resolve with the Redis command response.
    public func command(_ command: String, arguments: [RESPValue] = []) -> EventLoopFuture<RESPValue> {
        guard !_isClosed.load() else {
            return channel.eventLoop.makeFailedFuture(RedisError.connectionClosed)
        }

        let promise = channel.eventLoop.makePromise(of: RESPValue.self)
        let context = RedisCommandContext(
            command: .array([RESPValue(bulk: command)] + arguments),
            promise: promise
        )

        _ = channel.writeAndFlush(context)

        return promise.futureResult
    }

    /// Creates a `RedisPipeline` for executing a batch of commands.
    public func makePipeline() -> RedisPipeline {
        return .init(channel: channel)
    }
}
