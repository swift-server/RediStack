import Foundation
import NIORedis

public final class RedisConnection {
    private let driverConnection: NIORedisConnection
    private let queue: DispatchQueue

    deinit { driverConnection.close() }

    init(driver: NIORedisConnection, callbackQueue: DispatchQueue) {
        self.driverConnection = driver
        self.queue = callbackQueue
    }

    public func get(
        _ key: String,
        _ callback: @escaping (Result<String?, Error>
    ) -> Void) {
        // TODO: Make this a generic method to avoid copy/paste
        driverConnection.get(key)
            .map { result in
                self.queue.async { callback(.success(result)) }
            }
            .whenFailure { error in
                self.queue.async { callback(.failure(error)) }
            }
    }
}

