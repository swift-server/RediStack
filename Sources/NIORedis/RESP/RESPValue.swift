import Foundation

/// A representation of a Redis Serialization Protocol (RESP) primitive value.
///
/// See: https://redis.io/topics/protocol
public enum RESPValue {
    case null
    case simpleString(String)
    case bulkString(Data)
    case error(RedisError)
    case integer(Int)
    case array([RESPValue])

    /// Initializes a `bulkString` by converting the provided string input.
    public init(bulk: String) {
        self = .bulkString(Data(bulk.utf8))
    }
}

extension RESPValue: ExpressibleByStringLiteral {
    /// Initializes a bulk string from a String literal
    public init(stringLiteral value: String) {
        self = .bulkString(Data(value.utf8))
    }
}

extension RESPValue: ExpressibleByArrayLiteral {
    /// Initializes an array from an Array literal
    public init(arrayLiteral elements: RESPValue...) {
        self = .array(elements)
    }
}

extension RESPValue: ExpressibleByNilLiteral {
    /// Initializes null from a nil literal
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension RESPValue: ExpressibleByIntegerLiteral {
    /// Initializes an integer from an integer literal
    public init(integerLiteral value: Int) {
        self = .integer(value)
    }
}

extension RESPValue {
    /// Extracted value of `simpleString` and `bulkString` representations.
    /// - Important: `bulkString` conversions to `String` assume UTF-8 encoding. Use the `data` property in other encodings.
    public var string: String? {
        switch self {
        case .simpleString(let string): return string
        case .bulkString(let data): return String(bytes: data, encoding: .utf8)
        default: return nil
        }
    }

    /// Extracted binary data from `bulkString` representations.
    public var data: Data? {
        guard case .bulkString(let data) = self else { return nil }
        return data
    }

    /// Extracted container of data elements from `array` representations.
    public var array: [RESPValue]? {
        guard case .array(let array) = self else { return nil }
        return array
    }

    /// Extracted value from `integer` representations.
    var int: Int? {
        guard case .integer(let int) = self else { return nil }
        return int
    }

    /// Returns `true` if this data is a "null" value from Redis.
    var isNull: Bool {
        switch self {
        case .null: return true
        default: return false
        }
    }

    /// Extracted value from `error` representations.
    var error: RedisError? {
        switch self {
        case .error(let error): return error
        default: return nil
        }
    }
}
