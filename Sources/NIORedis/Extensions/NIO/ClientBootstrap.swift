import Foundation
import NIO

extension ClientBootstrap {
    /// Makes a new `ClientBootstrap` instance with a default Redis `Channel` pipeline
    /// for sending and receiving messages in Redis Serialization Protocol (RESP) format.
    ///
    /// See `RESPEncoder`, `RESPDecoder`, and `RedisCommadHandler`
    /// - Parameter using: The `EventLoopGroup` to build the `ClientBootstrap` on.
    /// - Returns: A `ClientBootstrap` with the default configuration of a `Channel` pipeline for RESP messages.
    public static func makeRedisDefault(using group: EventLoopGroup) -> ClientBootstrap {
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
