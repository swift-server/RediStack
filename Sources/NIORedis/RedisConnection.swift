import NIO
import NIOConcurrencyHelpers

/// A connection to a Redis database instance, with the ability to send and receive commands.
///
///     let result = connection.send(command: "GET", arguments: ["my_key"]
///     // result == EventLoopFuture<RESPValue>
///
/// See https://redis.io/commands
public final class RedisConnection {
    /// The `Channel` this connection is associated with.
    public let channel: Channel

    /// Has the connection been closed?
    public private(set) var isClosed = Atomic<Bool>(value: false)

    deinit { assert(isClosed.load(), "Redis connection was not properly shut down!") }

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
        guard isClosed.exchange(with: true) else { return channel.eventLoop.makeSucceededFuture(result: ()) }

        let promise = channel.eventLoop.makePromise(of: Void.self)

        channel.close(promise: promise)

        return promise.futureResult
    }

    /// Sends the desired command with the specified arguments.
    /// - Parameters:
    ///     - command: The command to execute.
    ///     - arguments: The arguments to be sent with the command.
    /// - Returns: An `EventLoopFuture` that will resolve with the Redis command response.
    public func send(command: String, arguments: [RESPConvertible] = []) throws -> EventLoopFuture<RESPValue> {
        guard !isClosed.load() else {
            return channel.eventLoop.makeFailedFuture(error: RedisError.connectionClosed)
        }

        let promise = channel.eventLoop.makePromise(of: RESPValue.self)
        let args = try arguments.map { try $0.convertToRESP() }
        let context = RedisCommandContext(
            command: .array([RESPValue(bulk: command)] + args),
            promise: promise
        )

        #warning("TODO - Pipelining")
        _ = channel.writeAndFlush(context)

        return promise.futureResult
    }
}
