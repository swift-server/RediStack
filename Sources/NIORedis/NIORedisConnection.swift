import NIO
import NIOConcurrencyHelpers

public final class NIORedisConnection {
    /// The `EventLoop` this connection uses to execute commands on.
    public var eventLoop: EventLoop { return channel.eventLoop }

    /// Has the connection been closed?
    public private(set) var isClosed = Atomic<Bool>(value: false)

    internal let redisPipeline: RedisMessenger

    private let channel: Channel

    deinit { assert(!isClosed.load(), "Redis connection was not properly shut down!") }

    /// Creates a new connection on the provided channel, using the handler for executing commands.
    /// - Important: Call `close()` before deinitializing to properly cleanup resources!
    init(channel: Channel, handler: RedisMessenger) {
        self.channel = channel
        self.redisPipeline = handler
    }

    /// Closes the connection to Redis.
    public func close() {
        guard isClosed.exchange(with: true) else { return }

        channel.close(promise: nil)
    }

    /// Executes the desired command with the specified arguments.
    /// - Important: All arguments should be in `.bulkString` format.
    public func command(_ command: String, _ arguments: [RedisData] = []) -> EventLoopFuture<RedisData> {
        return send(.array([RedisData(bulk: command)] + arguments))
            .thenThrowing { response in
                switch response {
                case let .error(error): throw error
                default: return response
                }
            }
    }

    private func send(_ message: RedisData) -> EventLoopFuture<RedisData> {
        // ensure the connection is still open
        guard !isClosed.load() else { return eventLoop.makeFailedFuture(error: RedisError.connectionClosed) }

        // create a new promise to store
        let promise = eventLoop.makePromise(of: RedisData.self)

        // cascade this enqueue to the newly created promise
        redisPipeline.enqueue(message).cascade(promise: promise)

        return promise.futureResult
    }
}
