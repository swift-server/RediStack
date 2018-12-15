import Foundation

/// A representation of a Redis primitive value
///
/// See: https://redis.io/topics/protocol
public enum RedisData {
    case null
    case simpleString(String)
    case bulkString(Data)
    case error(RedisError)
    case integer(Int)
    case array([RedisData])
}

extension RedisData: ExpressibleByStringLiteral {
    /// Initializes a bulk string from a String literal
    public init(stringLiteral value: String) {
        self = .bulkString(Data(value.utf8))
    }
}

extension RedisData: ExpressibleByArrayLiteral {
    /// Initializes an array from an Array literal
    public init(arrayLiteral elements: RedisData...) {
        self = .array(elements)
    }
}

extension RedisData: ExpressibleByNilLiteral {
    /// Initializes null from a nil literal
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension RedisData: ExpressibleByIntegerLiteral {
    /// Initializes an integer from an integer literal
    public init(integerLiteral value: Int) {
        self = .integer(value)
    }
}

// Internal convienence computed properties

extension RedisData {
    /// Extracts the basic/bulk string as a `String`.
    var string: String? {
        switch self {
        case .simpleString(let string): return string
        case .bulkString(let data): return String(bytes: data, encoding: .utf8)
        default: return nil
        }
    }

    /// Extracts the binary data from a Redis BulkString
    var data: Data? {
        guard case .bulkString(let data) = self else { return nil }
        return data
    }

    /// Extracts an array type from this data
    var array: [RedisData]? {
        guard case .array(let array) = self else { return nil }
        return array
    }

    /// Extracts an array type from this data
    var int: Int? {
        guard case .integer(let int) = self else { return nil }
        return int
    }

    /// `true` if this data is null.
    var isNull: Bool {
        switch self {
        case .null: return true
        default: return false
        }
    }

    /// Extracts an error from this data
    var error: RedisError? {
        switch self {
        case .error(let error): return error
        default: return nil
        }
    }
}
