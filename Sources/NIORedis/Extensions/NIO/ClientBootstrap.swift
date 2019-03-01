import Foundation
import NIO

extension ClientBootstrap {
    /// Makes a new `ClientBootstrap` instance with a standard Redis `Channel` pipeline for sending and receiving
    /// messages in Redis Serialization Protocol (RESP) format.
    ///
    /// See `RESPEncoder`, `RESPDecoder`, and `RedisCommadHandler`.
    /// - Parameter using: The `EventLoopGroup` to build the `ClientBootstrap` on.
    /// - Returns: A `ClientBootstrap` with the standard configuration of a `Channel` pipeline for RESP messages.
    public static func makeForRedis(using group: EventLoopGroup) -> ClientBootstrap {
        return ClientBootstrap(group: group)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer { channel in
                let handlers: [ChannelHandler] = [
                    RESPEncoder(),
                    ByteToMessageHandler(RESPDecoder()),
                    RedisCommandHandler()
                ]
                return .andAllSucceed(handlers.map { channel.pipeline.addHandler($0) }, on: group.next())
            }
    }
}
