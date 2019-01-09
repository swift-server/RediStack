import NIO
import NIOConcurrencyHelpers

/// A factory that handles all necessary details for creating connections to a Redis database instance.
public final class NIORedis {
    /// The threading model to use for asynchronous tasks.
    ///
    /// Using `.eventLoopGroup` will allow an external provider to handle the lifetime of the `EventLoopGroup`,
    /// while using `spawnThreads` will cause this `NIORedis` instance to handle the lifetime of a new `EventLoopGroup`.
    public enum ExecutionModel {
        case spawnThreads(Int)
        case eventLoopGroup(EventLoopGroup)
    }

    private let executionModel: ExecutionModel
    private let elg: EventLoopGroup
    private let isRunning = Atomic<Bool>(value: true)

    deinit { assert(!isRunning.load(), "Redis driver was not properly shut down!") }

    /// Creates a handle to create connections to a Redis instance using the `ExecutionModel` provided.
    /// - Parameter executionModel: The model to use for handling asynchronous scheduling.
    public init(executionModel model: ExecutionModel) {
        self.executionModel = model

        switch model {
        case .spawnThreads(let count):
            self.elg = MultiThreadedEventLoopGroup(numberOfThreads: count)
        case .eventLoopGroup(let group):
            self.elg = group
        }
    }

    /// Creates a new `NIORedisConnection` with the connection parameters provided.
    public func makeConnection(
        hostname: String = "localhost",
        port: Int = 6379,
        password: String? = nil
    ) -> EventLoopFuture<NIORedisConnection> {
        let channelHandler = RedisMessenger(on: elg.next())
        let bootstrap = ClientBootstrap(group: self.elg)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                return channel.pipeline.addHandlers(
                    RESPEncoder(),
                    ByteToMessageHandler(RESPDecoder()),
                    channelHandler
                )
            }

        return bootstrap.connect(host: hostname, port: port)
            .map { return NIORedisConnection(channel: $0, handler: channelHandler) }
            .then { connection in
                guard let pw = password else {
                    return self.elg.next().makeSucceededFuture(result: connection)
                }

                return connection.authorize(with: pw).map { _ in return connection }
            }
    }

    /// Handles the proper shutdown of managed resources.
    /// - Important: This method should always be called before deinit.
    public func terminate() throws {
        guard isRunning.exchange(with: false) else { return }

        switch executionModel {
        case .spawnThreads: try self.elg.syncShutdownGracefully()
        case .eventLoopGroup: return
        }
    }
}

private extension ChannelPipeline {
    func addHandlers(_ handlers: ChannelHandler...) -> EventLoopFuture<Void> {
        return EventLoopFuture<Void>.andAll(handlers.map { add(handler: $0) }, eventLoop: eventLoop)
    }
}
