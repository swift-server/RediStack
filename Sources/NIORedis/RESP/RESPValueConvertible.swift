import Foundation

/// Capable of converting to / from `RESPValue`.
public protocol RESPValueConvertible {
    init?(_ value: RESPValue)

    /// Creates a `RESPValue` representation.
    func convertedToRESPValue() -> RESPValue
}

extension RESPValue: RESPValueConvertible {
    public init?(_ value: RESPValue) {
        self = value
    }

    /// See `RESPValueConvertible.convertedToRESPValue()`
    public func convertedToRESPValue() -> RESPValue {
        return self
    }
}

extension RedisError: RESPValueConvertible {
    public init?(_ value: RESPValue) {
        guard let error = value.error else { return nil }
        self = error
    }

    /// See `RESPValueConvertible.convertedToRESPValue()`
    public func convertedToRESPValue() -> RESPValue {
        return .error(self)
    }
}

extension String: RESPValueConvertible {
    public init?(_ value: RESPValue) {
        guard let string = value.string else { return nil }
        self = string
    }

    /// See `RESPValueConvertible.convertedToRESPValue()`
    public func convertedToRESPValue() -> RESPValue {
        return .bulkString(Data(self.utf8))
    }
}

extension FixedWidthInteger {
    public init?(_ value: RESPValue) {
        if let int = value.int {
            self = Self(int)
        } else {
            guard let string = value.string else { return nil }
            guard let int = Self(string) else { return nil }
            self = Self(int)
        }
    }

    /// See `RESPValueConvertible.convertedToRESPValue()`
    public func convertedToRESPValue() -> RESPValue {
        return .bulkString(Data(self.description.utf8))
    }
}

extension Int: RESPValueConvertible {}
extension Int8: RESPValueConvertible {}
extension Int16: RESPValueConvertible {}
extension Int32: RESPValueConvertible {}
extension Int64: RESPValueConvertible {}
extension UInt: RESPValueConvertible {}
extension UInt8: RESPValueConvertible {}
extension UInt16: RESPValueConvertible {}
extension UInt32: RESPValueConvertible {}
extension UInt64: RESPValueConvertible {}

extension Double: RESPValueConvertible {
    public init?(_ value: RESPValue) {
        guard let string = value.string else { return nil }
        guard let float = Double(string) else { return nil }
        self = float
    }

    /// See `RESPValueConvertible.convertedToRESPValue()`
    public func convertedToRESPValue() -> RESPValue {
        return .bulkString(Data(self.description.utf8))
    }
}

extension Float: RESPValueConvertible {
    public init?(_ value: RESPValue) {
        guard let string = value.string else { return nil }
        guard let float = Float(string) else { return nil }
        self = float
    }

    /// See `RESPValueConvertible.convertedToRESPValue()`
    public func convertedToRESPValue() -> RESPValue {
        return .bulkString(Data(self.description.utf8))
    }
}

extension Data: RESPValueConvertible {
    public init?(_ value: RESPValue) {
        guard let data = value.data else { return nil }
        self = data
    }

    /// See `RESPValueConvertible.convertedToRESPValue()`
    public func convertedToRESPValue() -> RESPValue {
        return .bulkString(self)
    }
}

extension Array: RESPValueConvertible where Element: RESPValueConvertible {
    public init?(_ value: RESPValue) {
        guard let array = value.array else { return nil }
        self = array.compactMap { Element($0) }
    }

    /// See `RESPValueConvertible.convertedToRESPValue()`
    public func convertedToRESPValue() -> RESPValue {
        let elements = map { $0.convertedToRESPValue() }
        return RESPValue.array(elements)
    }
}
