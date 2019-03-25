
@testable import NIORedis
import Foundation

extension RedisConnection {
    static func connect(
        on elg: EventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    ) throws -> EventLoopFuture<RedisConnection> {
        return RedisConnection.connect(to: try .init(ipAddress: "127.0.0.1", port: 6379), on: elg)
    }
}
