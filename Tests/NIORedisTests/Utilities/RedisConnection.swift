@testable import NIORedis

extension Redis {
    static func makeConnection() throws -> EventLoopFuture<RedisConnection> {
        return Redis.makeConnection(
            to: try .init(ipAddress: "127.0.0.1", port: 6379),
            using: MultiThreadedEventLoopGroup(numberOfThreads: 1)
        )
    }
}
