import Foundation

/// Errors thrown while working with Redis.
public struct RedisError: CustomDebugStringConvertible, CustomStringConvertible, LocalizedError {
    public let description: String
    public let debugDescription: String

    public init(
        identifier: String,
        reason: String,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        let name = String(describing: type(of: self))
        description = "⚠️ [\(name).\(identifier): \(reason)]"
        debugDescription = "⚠️ Redis Error: \(reason)\n- id: \(name).\(identifier)\n\n\(Thread.callStackSymbols)"
    }
}
