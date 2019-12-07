extension RedisClient {
    /// Returns a new `RedisClient` that will log to the supplied logger by default.
    /// - Parameters:
    ///    - logger:  New logger to log to by default
    /// - Returns: New `RedisClient` with logger overridden.
    public func logging(to logger: Logger) -> RedisClient {
        CustomLoggerRedisClient(client: self, logger: logger)
    }
}

private struct CustomLoggerRedisClient {
    let client: RedisClient
    let logger: Logger
}

extension CustomLoggerRedisClient: RedisClient {
    var eventLoop: EventLoop {
        self.client.eventLoop
    }

    func send(command: String, with arguments: [RESPValue], logger: Logger) -> EventLoopFuture<RESPValue> {
        self.client.send(command: command, with: arguments, logger: logger)
    }
}
