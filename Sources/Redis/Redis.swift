import Foundation
import NIO
import NIORedis

/// A factory that handles all necessary details for creating `RedisConnection` instances.
public final class Redis {
    private let driver: NIORedis

    deinit { try? driver.terminate() }

    public init(threadCount: Int = 1) {
        self.driver = NIORedis(executionModel: .spawnThreads(threadCount))
    }

    public func makeConnection(
        hostname: String = "localhost",
        port: Int = 6379,
        password: String? = nil,
        queue: DispatchQueue = .main,
        _ callback: @escaping (Result<RedisConnection, Error>) -> Void
    ) {
        driver.makeConnection(hostname: hostname, port: port, password: password)
            .map {
                let connection = RedisConnection(driver: $0, callbackQueue: queue)
                queue.async {
                    callback(.success(connection))
                }
            }
            .whenFailure { error in
                queue.async {
                    callback(.failure(error))
                }
            }
    }
}
