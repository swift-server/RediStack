import NIO
import NIOConcurrencyHelpers

public final class RedisDriver {
    /// The threading model to use for asynchronous tasks.
    ///
    /// Using `.eventLoopGroup` will allow an external provider to handle the lifetime of the `EventLoopGroup`,
    /// while using `spawnThreads` will cause this `NIORedis` instance to handle the lifetime of a new `EventLoopGroup`.
    public enum ExecutionModel {
        case spawnThreads(Int)
        case eventLoopGroup(EventLoopGroup)
    }

    private let executionModel: ExecutionModel
    private let eventLoopGroup: EventLoopGroup

    private let isRunning = Atomic<Bool>(value: true)

    deinit { assert(!isRunning.load(), "Redis driver was not properly shut down!") }

    /// Creates a driver instance to create connections to a Redis.
    /// - Important: Call `terminate()` before deinitializing to properly cleanup resources.
    /// - Parameter executionModel: The model to use for handling connection resources.
    public init(executionModel model: ExecutionModel) {
        self.executionModel = model

        switch model {
        case .spawnThreads(let count):
            self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: count)
        case .eventLoopGroup(let group):
            self.eventLoopGroup = group
        }
    }

    /// Handles the proper shutdown of managed resources.
    /// - Important: This method should always be called, even when running in `.eventLoopGroup` mode.
    public func terminate() throws {
        guard isRunning.exchange(with: false) else { return }

        switch executionModel {
        case .spawnThreads: try self.eventLoopGroup.syncShutdownGracefully()
        case .eventLoopGroup: return
        }
    }

    /// Creates a new `RedisConnection` with the parameters provided.
    public func makeConnection(
        hostname: String = "localhost",
        port: Int = 6379,
        password: String? = nil
    ) -> EventLoopFuture<RedisConnection> {
        let bootstrap = ClientBootstrap(group: eventLoopGroup)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                return channel.pipeline.addHandlers(
                    RESPEncoder(),
                    ByteToMessageHandler(RESPDecoder()),
                    RedisCommandHandler()
                )
            }

        return bootstrap.connect(host: hostname, port: port)
            .map { return RedisConnection(channel: $0) }
            .then { connection in
                guard let pw = password else {
                    return self.eventLoopGroup.next().makeSucceededFuture(result: connection)
                }

                return connection.authorize(with: pw).map { _ in return connection }
            }
    }
}

private extension ChannelPipeline {
    func addHandlers(_ handlers: ChannelHandler...) -> EventLoopFuture<Void> {
        return EventLoopFuture<Void>.andAll(handlers.map { add(handler: $0) }, eventLoop: eventLoop)
    }
}
