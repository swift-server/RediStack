//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2019 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import protocol Foundation.LocalizedError
import NIO

/// A helper object for translating between raw bytes and Swift types according to the Redis Serialization Protocol (RESP).
///
/// See [https://redis.io/topics/protocol](https://redis.io/topics/protocol)
public struct RESPTranslator {
    public init() { }
}

// MARK: Writing RESP

/// The carriage return and newline escape symbols, used as the standard signal in RESP for a "message" end.
/// A "message" in this case is a single data type.
fileprivate let respEnd: StaticString = "\r\n"

extension ByteBuffer {
    /// Writes the `RESPValue` into the current buffer, following the RESP specification.
    ///
    /// See [https://redis.io/topics/protocol](https://redis.io/topics/protocol)
    /// - Parameter value: The value to write to the buffer.
    public mutating func writeRESPValue(_ value: RESPValue) {
        switch value {
        case .simpleString(var buffer):
            self.writeStaticString("+")
            self.writeBuffer(&buffer)
            self.writeStaticString(respEnd)
            
        case .bulkString(.some(var buffer)):
            self.writeStaticString("$")
            self.writeString("\(buffer.readableBytes)")
            self.writeStaticString(respEnd)
            self.writeBuffer(&buffer)
            self.writeStaticString(respEnd)
            
        case .bulkString(.none):
            self.writeStaticString("$0\r\n\r\n")
            
        case .integer(let number):
            self.writeStaticString(":")
            self.writeString(number.description)
            self.writeStaticString(respEnd)
            
        case .null:
            self.writeStaticString("$-1\r\n")
            
        case .error(let error):
            self.writeStaticString("-")
            self.writeString(error.message)
            self.writeStaticString(respEnd)
            
        case .array(let array):
            self.writeStaticString("*")
            self.writeString("\(array.count)")
            self.writeStaticString(respEnd)
            array.forEach { self.writeRESPValue($0) }
        }
    }
}

extension RESPTranslator {
    /// Writes the value into the desired `ByteBuffer` in RESP format.
    /// - Parameters:
    ///     - value: The value to write into the buffer.
    ///     - out: The `ByteBuffer` that should be written to.
    public func write<Value: RESPValueConvertible>(_ value: Value, into out: inout ByteBuffer) {
        out.writeRESPValue(value.convertedToRESPValue())
    }
}

// MARK: Reading RESP

extension UInt8 {
    static let newline = UInt8(ascii: "\n")
    static let carriageReturn = UInt8(ascii: "\r")
    static let dollar = UInt8(ascii: "$")
    static let asterisk = UInt8(ascii: "*")
    static let plus = UInt8(ascii: "+")
    static let hyphen = UInt8(ascii: "-")
    static let colon = UInt8(ascii: ":")
}

extension RESPTranslator {
    /// Representation of a `Swift.Error` found during RESP parsing.
    /// - Important: Any of these errors should be considered a **BUG**.
    ///
    /// If you believe this is a bug from the `RESPTranslator`, file a bug at
    /// [https://www.gitlab.com/mordil/swift-redis-nio-client/issues](https://www.gitlab.com/mordil/swift-redis-nio-client/issues)
    public enum ParsingError: LocalizedError {
        case invalidToken
        case invalidBulkStringSize
        case bulkStringSizeMismatch
        case invalidIntegerFormat
        
        /// See `LocalizedError.errorDescription`
        public var errorDescription: String? {
            switch self {
            case .invalidToken: return "Cannot parse RESP: Invalid Token"
            case .invalidBulkStringSize: return "Cannot parse RESP Bulk String: Received invalid size."
            case .bulkStringSizeMismatch: return "Cannot parse RESP Bulk String: Declared Size and Content Size do not match."
            case .invalidIntegerFormat: return "Cannot parse RESP integer: invalid integer format"
            }
        }
    }
    
    /// Attempts to parse a `RESPValue` from the `ByteBuffer`.
    /// - Important: The provided `buffer` will have its reader index moved on a successful parse.
    /// - Throws:
    ///     - `RESPTranslator.ParsingError.invalidToken` if the first byte is not an expected RESP Data Type token.
    /// - Parameter buffer: The buffer that contains the bytes that need to be parsed.
    /// - Returns: The parsed `RESPValue` or nil.
    public func parseBytes(from buffer: inout ByteBuffer) throws -> RESPValue? {
        var copy = buffer

        guard let token = copy.readInteger(as: UInt8.self) else { return nil }
        
        let result: RESPValue?
        switch token {
        case .plus:
            guard let value = self.parseSimpleString(from: &copy) else { return nil }
            result = .simpleString(value)
            
        case .colon:
            guard let value = try self.parseInteger(from: &copy) else { return nil }
            result = .integer(value)
            
        case .dollar:
            result = try self.parseBulkString(from: &copy)
            break
            
        case .asterisk:
            result = try self.parseArray(from: &copy)
            break
            
        case .hyphen:
            guard
                let stringBuffer = self.parseSimpleString(from: &copy),
                let message = stringBuffer.getString(at: 0, length: stringBuffer.readableBytes)
            else { return nil }
            result = .error(RedisError(reason: message))
            
        default: throw ParsingError.invalidToken
        }
        
        // if we successfully parsed a value, we need to update the original buffer's readerIndex
        if result != nil {
            buffer.moveReaderIndex(to: copy.readerIndex)
        }
        
        return result
    }
    
    /// See [https://redis.io/topics/protocol#resp-simple-strings](https://redis.io/topics/protocol#resp-simple-strings)
    internal func parseSimpleString(from buffer: inout ByteBuffer) -> ByteBuffer? {
        let bytes = buffer.readableBytesView
        guard
            let newlineIndex = bytes.firstIndex(of: .newline),
            newlineIndex - bytes.startIndex >= 1 // strings should at least have a CRLF ending
        else { return nil }
        
        // grab the bytes that we've determined is the full simple string,
        // and make sure to move the reader index afterwards
        defer {
            buffer.moveReaderIndex(to: newlineIndex + 1)
        }
        // the length of the string will be the position (delta'd by the start index) - 1,
        // as the last character is just before the position of the newline escape
        let endIndex = newlineIndex - bytes.startIndex
        return buffer.getSlice(at: bytes.startIndex, length: endIndex - 1)
    }
    
    /// See [https://redis.io/topics/protocol#resp-integers](https://redis.io/topics/protocol#resp-integers)
    internal func parseInteger(from buffer: inout ByteBuffer) throws -> Int? {
        guard
            var stringBuffer = parseSimpleString(from: &buffer),
            let string = stringBuffer.readString(length: stringBuffer.readableBytes)
        else { return nil }

        guard let result = Int(string) else { throw ParsingError.invalidIntegerFormat }
        return result
    }
    
    /// See [https://redis.io/topics/protocol#resp-bulk-strings](https://redis.io/topics/protocol#resp-bulk-strings)
    internal func parseBulkString(from buffer: inout ByteBuffer) throws -> RESPValue? {
        guard let size = try self.parseInteger(from: &buffer) else {
            return nil
        }
        
        // only -1 is the only valid negative value for a size
        guard size >= -1 else { throw ParsingError.invalidBulkStringSize }
        
        // Redis sends '$-1\r\n' to represent a null bulk string
        guard size > -1 else { return .null }
        
        // Verify that we have the entire bulk string message by adding the expected CRLF end bytes
        // to the parsed size of the message content.
        // Even if the content is empty, Redis sends '$0\r\n\r\n'
        let expectedRemainingMessageSize = size + 2
        guard buffer.readableBytes >= expectedRemainingMessageSize else { return nil }
        
        // sanity check that the declared content size matches the actual size.
        guard
            buffer.getInteger(at: buffer.readerIndex + expectedRemainingMessageSize - 1, as: UInt8.self) == .newline
        else { throw ParsingError.bulkStringSizeMismatch }
        
        // empty content bulk strings are different from null, and represented as .bulkString(nil)
        guard size > 0 else {
            buffer.moveReaderIndex(forwardBy: 2)
            return .bulkString(nil)
        }
        
        // move the reader position forward by the size of the total message (including the CRLF ending)
        defer {
            buffer.moveReaderIndex(forwardBy: expectedRemainingMessageSize)
        }
        
        return .bulkString(
            buffer.getSlice(at: buffer.readerIndex, length: size)
        )
    }
    
    /// See [https://redis.io/topics/protocol#resp-arrays](https://redis.io/topics/protocol#resp-arrays)
    internal func parseArray(from buffer: inout ByteBuffer) throws -> RESPValue? {
        guard let elementCount = try parseInteger(from: &buffer) else { return nil }
        guard elementCount > -1 else { return .null } // '*-1\r\n'
        guard elementCount > 0 else { return .array([]) } // '*0\r\n'
        
        var results: [RESPValue] = []
        results.reserveCapacity(elementCount)
        
        for _ in 0..<elementCount {
            guard buffer.readableBytes > 0 else { return nil }
            guard let element = try self.parseBytes(from: &buffer) else { return nil }
            results.append(element)
        }
        
        return .array(results)
    }
}
