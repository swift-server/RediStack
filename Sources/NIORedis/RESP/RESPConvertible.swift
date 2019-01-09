import Foundation

/// Capable of converting to / from `RESPValue`.
public protocol RESPConvertible {
    /// Create an instance of `Self` from `RESPValue`.
    static func convertFromRESP(_ value: RESPValue) throws -> Self

    /// Convert self to `RESPValue`.
    func convertToRESP() throws -> RESPValue
}

extension RESPValue: RESPConvertible {
    /// See `RESPValueConvertible`.
    public func convertToRESP() throws -> RESPValue {
        return self
    }

    /// See `RESPValueConvertible`.
    public static func convertFromRESP(_ value: RESPValue) throws -> RESPValue {
        return value
    }
}

extension String: RESPConvertible {
    /// See `RESPValueConvertible`.
    public static func convertFromRESP(_ value: RESPValue) throws -> String {
        guard let string = value.string else {
            throw RedisError(identifier: "string", reason: "Could not convert to string: \(value).")
        }
        return string
    }

    /// See `RESPValueConvertible`.
    public func convertToRESP() throws -> RESPValue {
        return .bulkString(Data(self.utf8))
    }
}

extension FixedWidthInteger {
    /// See `RESPValueConvertible`.
    public static func convertFromRESP(_ value: RESPValue) throws -> Self {
        guard let int = value.int else {
            guard let string = value.string else {
                throw RedisError(identifier: "string", reason: "Could not convert to string: \(value)")
            }

            guard let int = Self(string) else {
                throw RedisError(identifier: "int", reason: "Could not convert to int: \(value)")
            }

            return int
        }

        return Self(int)
    }

    /// See `RESPValueConvertible`.
    public func convertToRESP() throws -> RESPValue {
        return .bulkString(Data(self.description.utf8))
    }
}

extension Int: RESPConvertible {}
extension Int8: RESPConvertible {}
extension Int16: RESPConvertible {}
extension Int32: RESPConvertible {}
extension Int64: RESPConvertible {}
extension UInt: RESPConvertible {}
extension UInt8: RESPConvertible {}
extension UInt16: RESPConvertible {}
extension UInt32: RESPConvertible {}
extension UInt64: RESPConvertible {}

extension Double: RESPConvertible {
    /// See `RESPValueConvertible`.
    public static func convertFromRESP(_ value: RESPValue) throws -> Double {
        guard let string = value.string else {
            throw RedisError(identifier: "string", reason: "Could not convert to string: \(value).")
        }

        guard let float = Double(string) else {
            throw RedisError(identifier: "double", reason: "Could not convert to double: \(value).")
        }

        return float
    }

    /// See `RESPValueConvertible`.
    public func convertToRESP() throws -> RESPValue {
        return .bulkString(Data(self.description.utf8))
    }
}

extension Float: RESPConvertible {
    /// See `RESPValueConvertible`.
    public static func convertFromRESP(_ value: RESPValue) throws -> Float {
        guard let string = value.string else {
            throw RedisError(identifier: "string", reason: "Could not convert to string: \(value).")
        }

        guard let float = Float(string) else {
            throw RedisError(identifier: "float", reason: "Could not convert to float: \(value).")
        }

        return float
    }

    /// See `RESPValueConvertible`.
    public func convertToRESP() throws -> RESPValue {
        return .bulkString(Data(self.description.utf8))
    }
}

extension Data: RESPConvertible {
    /// See `RESPValueConvertible`.
    public static func convertFromRESP(_ value: RESPValue) throws -> Data {
        guard let theData = value.data else {
            throw RedisError(identifier: "data", reason: "Could not convert to data: \(value).")
        }
        return theData
    }

    /// See `RESPValueConvertible`.
    public func convertToRESP() throws -> RESPValue {
        return .bulkString(self)
    }
}

extension Array: RESPConvertible where Element: RESPConvertible {
    /// See `RESPValueConvertible`.
    public static func convertFromRESP(_ value: RESPValue) throws -> Array<Element> {
        guard let array = value.array else {
            throw RedisError(identifier: "array", reason: "Could not convert to array: \(value).")
        }
        return try array.map { try Element.convertFromRESP($0) }
    }

    /// See `RESPValueConvertible`.
    public func convertToRESP() throws -> RESPValue {
        let dataArray = try map { try $0.convertToRESP() }
        return RESPValue.array(dataArray)
    }
}
