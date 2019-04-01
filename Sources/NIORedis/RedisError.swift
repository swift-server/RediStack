import protocol Foundation.LocalizedError
import class Foundation.Thread

/// Errors thrown while working with Redis.
public struct RedisError: CustomDebugStringConvertible, CustomStringConvertible, LocalizedError {
    public let description: String
    public let debugDescription: String

    public init(
        identifier: String,
        reason: String,
        file: StaticString = #file,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        let name = String(describing: type(of: self))
        description = "⚠️ [\(name).\(identifier): \(reason)]"
        debugDescription = "⚠️ Redis Error: \(reason)\n- id: \(name).\(identifier)\n\n\(file): L\(line) - \(function)\n\n\(Thread.callStackSymbols)"
    }
}

extension RedisError {
    internal static var connectionClosed: RedisError {
        return RedisError(identifier: "connection", reason: "Connection was closed while trying to execute.")
    }

    internal static func respConversion<T>(to dest: T.Type) -> RedisError {
        return RedisError(identifier: "respConversion", reason: "Failed to convert RESP to \(String(describing: dest))")
    }
}
