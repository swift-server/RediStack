import NIO
import NIOConcurrencyHelpers

/// An object capable of sending commands and receiving responses.
///
///     let executor = ...
///     let result = executor.send(command: "GET", arguments: ["my_key"]
///     // result == EventLoopFuture<RESPValue>
///
/// See [https://redis.io/commands](https://redis.io/commands)
public protocol RedisCommandExecutor {
    /// The `EventLoop` that this executor operates on.
    var eventLoop: EventLoop { get }

    /// Sends the desired command with the specified arguments.
    /// - Parameters:
    ///     - command: The command to execute.
    ///     - arguments: The arguments, if any, to be sent with the command.
    /// - Returns: An `EventLoopFuture` that will resolve with the Redis command response.
    func send(command: String, with arguments: [RESPValueConvertible]) -> EventLoopFuture<RESPValue>
}

extension RedisCommandExecutor {
    /// Sends the desired command without arguments.
    /// - Parameter command: The command keyword to execute.
    /// - Returns: An `EventLoopFuture` that will resolve with the Redis command response.
    func send(command: String) -> EventLoopFuture<RESPValue> {
        return self.send(command: command, with: [])
    }
}

/// An individual connection to a Redis database instance for executing commands or building `RedisPipeline`s.
///
/// See `RedisCommandExecutor`.
public protocol RedisConnection: AnyObject, RedisCommandExecutor {
    /// The `Channel` this connection is associated with.
    var channel: Channel { get }
    /// Has the connection been closed?
    var isClosed: Bool { get }

    /// Creates a `RedisPipeline` for executing a batch of commands.
    func makePipeline() -> RedisPipeline

    /// Closes the connection to Redis.
    /// - Returns: An `EventLoopFuture` that resolves when the connection has been closed.
    @discardableResult
    func close() -> EventLoopFuture<Void>
}

extension RedisConnection {
    public var eventLoop: EventLoop { return self.channel.eventLoop }
}

/// A basic `RedisConnection`.
public final class NIORedisConnection: RedisConnection {
    /// See `RedisConnection.channel`.
    public let channel: Channel

    /// See `RedisConnection.isClosed`.
    public var isClosed: Bool { return _isClosed.load() }
    private var _isClosed = Atomic<Bool>(value: false)

    deinit { assert(_isClosed.load(), "Redis connection was not properly shut down!") }

    /// Creates a new connection on the provided channel.
    /// - Note: This connection will take ownership of the `Channel` object.
    /// - Important: Call `close()` before deinitializing to properly cleanup resources.
    public init(channel: Channel) {
        self.channel = channel
    }

    /// See `RedisConnection.close()`.
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

    /// See `RedisConnection.makePipeline()`.
    public func makePipeline() -> RedisPipeline {
        return NIORedisPipeline(channel: channel)
    }

    /// See `RedisCommandExecutor.send(command:with:)`.
    public func send(command: String, with arguments: [RESPValueConvertible] = []) -> EventLoopFuture<RESPValue> {
        guard !_isClosed.load() else { return channel.eventLoop.makeFailedFuture(RedisError.connectionClosed) }

        let args = arguments.map { $0.convertedToRESPValue() }

        let promise = channel.eventLoop.makePromise(of: RESPValue.self)
        let context = RedisCommandContext(
            command: .array([RESPValue(bulk: command)] + args),
            promise: promise
        )

        _ = channel.writeAndFlush(context)

        return promise.futureResult
    }
}
