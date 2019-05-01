import struct Logging.Logger
import NIO

/// Top-level namespace for the `NIORedis` package.
///
/// To avoid a cluttered global namespace, named definitions that do not start with a `Redis` prefix
/// are scoped within this namespace.
public enum Redis { }

// MARK: ClientBootstrap

extension Redis {
    /// Makes a new `ClientBootstrap` instance with a default Redis `Channel` pipeline
    /// for sending and receiving messages in Redis Serialization Protocol (RESP) format.
    ///
    /// See `RESPEncoder`, `RESPDecoder`, and `CommandHandler`.
    /// - Parameter using: The `EventLoopGroup` to build the `ClientBootstrap` on.
    /// - Returns: A `ClientBootstrap` with the default configuration of a `Channel` pipeline for RESP messages.
    public static func makeDefaultClientBootstrap(using group: EventLoopGroup) -> ClientBootstrap {
        return ClientBootstrap(group: group)
            .channelOption(
                ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR),
                value: 1
            )
            .channelInitializer { $0.pipeline.addHandlers([
                MessageToByteHandler(RESPEncoder()),
                ByteToMessageHandler(RESPDecoder()),
                RedisCommandHandler()
            ])}
    }
}

// MARK: Connection Factory

extension Redis {
    /// Makes a new connection to a Redis instance.
    ///
    /// Example:
    ///
    ///     let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    ///     let connection = Redis.makeConnection(
    ///         to: .init(ipAddress: "127.0.0.1", port: 6379),
    ///         using: elg
    ///     )
    ///
    /// - Parameters:
    ///     - socket: The `SocketAddress` information of the Redis instance to connect to.
    ///     - password: The optional password to authorize the client with.
    ///     - eventLoopGroup: The `EventLoopGroup` to build the connection on.
    ///     - logger: The `Logger` instance to log with.
    /// - Returns: A `RedisConnection` instance representing this new connection.
    public static func makeConnection(
        to socket: SocketAddress,
        using group: EventLoopGroup,
        with password: String? = nil,
        logger: Logger = Logger(label: "NIORedis.RedisConnection")
    ) -> EventLoopFuture<RedisConnection> {
        let bootstrap = makeDefaultClientBootstrap(using: group)

        return bootstrap.connect(to: socket)
            .map { return RedisConnection(channel: $0, logger: logger) }
            .flatMap { client in
                guard let pw = password else {
                    return group.next().makeSucceededFuture(client)
                }

                return client.send(command: "AUTH", with: [pw])
                    .map { _ in return client }
            }
    }
}
