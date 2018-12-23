import Foundation
import NIORedis

public final class RedisConnection {
    private let driverConnection: NIORedisConnection
    private let queue: DispatchQueue

    init(driver: NIORedisConnection, callbackQueue: DispatchQueue) {
        self.driverConnection = driver
        self.queue = callbackQueue
    }

    public func get(
        _ key: String,
        queue: DispatchQueue = .main,
        _ callback: @escaping (Result<String?, Error>
    ) -> Void) {
        // TODO: Make this a generic method to avoid copy/paste
        driverConnection.get(key)
            .map { result in
                queue.async { callback(.success(result)) }
            }
            .whenFailure { error in
                queue.async { callback(.failure(error)) }
            }
    }
}

