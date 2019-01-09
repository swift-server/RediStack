import Foundation
import NIORedis

public final class RedisConnection {
    let _driverConnection: NIORedisConnection

    private let queue: DispatchQueue

    deinit { _driverConnection.close() }

    init(driver: NIORedisConnection, callbackQueue: DispatchQueue) {
        self._driverConnection = driver
        self.queue = callbackQueue
    }

    /// Creates a `RedisPipeline` for executing a batch of commands.
    public func makePipeline(callbackQueue: DispatchQueue? = nil) -> RedisPipeline {
        return .init(using: self, callbackQueue: callbackQueue ?? queue)
    }

    public func get(
        _ key: String,
        _ callback: @escaping (Result<String?, Error>
    ) -> Void) {
        // TODO: Make this a generic method to avoid copy/paste
        _driverConnection.get(key)
            .map { result in
                self.queue.async { callback(.success(result)) }
            }
            .whenFailure { error in
                self.queue.async { callback(.failure(error)) }
            }
    }
}

