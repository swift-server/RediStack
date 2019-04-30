import protocol Foundation.LocalizedError

/// When working with NIORedis, several errors are thrown to indicate problems
/// with state, assertions, or otherwise.
public enum NIORedisError: LocalizedError {
    case connectionClosed
    case responseConversion(to: Any.Type)
    case unsupportedOperation(method: StaticString, message: String)
    case assertionFailure(message: String)

    public var errorDescription: String? {
        let message: String
        switch self {
        case .connectionClosed: message = "Connection was closed while trying to send command."
        case let .responseConversion(type): message = "Failed to convert RESP to \(type)"
        case let .unsupportedOperation(method, helpText): message = "\(method) - \(helpText)"
        case let .assertionFailure(text): message = text
        }
        return "NIORedis: \(message)"
    }
}

/// When sending commands to a Redis server, errors caught will be returned as an error message.
/// These messages are represented by `RedisError` instances.
public struct RedisError: LocalizedError {
    public let message: String

    public var errorDescription: String? { return message }

    public init(reason: String) {
        message = "Redis: \(reason)"
    }
}
