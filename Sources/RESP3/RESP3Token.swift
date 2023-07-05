//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2023 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOCore

struct RESP3Token: Hashable, Sendable {
    struct Array: Sequence, Sendable, Hashable {
        typealias Element = RESP3Token

        let count: Int
        let buffer: ByteBuffer

        func makeIterator() -> Iterator {
            Iterator(buffer: self.buffer)
        }

        struct Iterator: IteratorProtocol {
            typealias Element = RESP3Token

            private var buffer: ByteBuffer

            fileprivate init(buffer: ByteBuffer) {
                self.buffer = buffer
            }

            mutating func next() -> RESP3Token? {
                return try! RESP3Token(consuming: &self.buffer)
            }
        }
    }

    struct Map: Sequence, Sendable, Hashable {
        typealias Element = (key: RESP3Token, value: RESP3Token)

        let count: Int
        let underlying: Array

        init(count: Int, buffer: ByteBuffer) {
            self.count = count
            self.underlying = Array(count: count * 2, buffer: buffer)
        }

        func makeIterator() -> Iterator {
            Iterator(underlying: self.underlying.makeIterator())
        }

        struct Iterator: IteratorProtocol {
            typealias Element = (key: RESP3Token, value: RESP3Token)

            private var underlying: Array.Iterator

            fileprivate init(underlying: Array.Iterator) {
                self.underlying = underlying
            }

            mutating func next() -> (key: RESP3Token, value: RESP3Token)? {
                guard let key = self.underlying.next() else {
                    return nil
                }

                let value = self.underlying.next()!
                return (key, value)
            }
        }
    }

    enum Value: Hashable {
        case simpleString(ByteBuffer)
        case simpleError(ByteBuffer)
        case blobString(ByteBuffer)
        case blobError(ByteBuffer)
        case verbatimString(ByteBuffer)
        case number(Int64)
        case double(Double)
        case boolean(Bool)
        case null
        case bigNumber(ByteBuffer)
        case array(Array)
        case attribute(Map)
        case map(Map)
        case set(Array)
        case push(Array)
    }

    let base: ByteBuffer

    var value: Value {
        var local = self.base

        switch local.readValidatedRESP3TypeIdentifier() {
        case .null:
            return .null

        case .boolean:
            return .boolean(local.readInteger(as: UInt8.self)! == .t)

        case .blobString:
            var lengthSlice = try! local.readCRLFTerminatedSlice2()!
            let lengthString = lengthSlice.readString(length: lengthSlice.readableBytes)!
            let length = Int(lengthString)!
            return .blobString(local.readSlice(length: length)!)

        case .blobError:
            var lengthSlice = try! local.readCRLFTerminatedSlice2()!
            let lengthString = lengthSlice.readString(length: lengthSlice.readableBytes)!
            let length = Int(lengthString)!
            return .blobError(local.readSlice(length: length)!)

        case .simpleString:
            let slice = try! local.readCRLFTerminatedSlice2()!
            return .simpleString(slice)

        case .simpleError:
            let slice = try! local.readCRLFTerminatedSlice2()!
            return .simpleError(slice)

        case .array:
            var countSlice = try! local.readCRLFTerminatedSlice2()!
            let countString = countSlice.readString(length: countSlice.readableBytes)!
            let count = Int(countString)!
            return .array(.init(count: count, buffer: local))

        case .push:
            var countSlice = try! local.readCRLFTerminatedSlice2()!
            let countString = countSlice.readString(length: countSlice.readableBytes)!
            let count = Int(countString)!
            return .push(.init(count: count, buffer: local))

        case .set:
            var countSlice = try! local.readCRLFTerminatedSlice2()!
            let countString = countSlice.readString(length: countSlice.readableBytes)!
            let count = Int(countString)!
            return .set(.init(count: count, buffer: local))

        case .attribute:
            var countSlice = try! local.readCRLFTerminatedSlice2()!
            let countString = countSlice.readString(length: countSlice.readableBytes)!
            let count = Int(countString)!
            return .attribute(.init(count: count, buffer: local))

        case .map:
            var countSlice = try! local.readCRLFTerminatedSlice2()!
            let countString = countSlice.readString(length: countSlice.readableBytes)!
            let count = Int(countString)!
            return .map(.init(count: count, buffer: local))

        case .integer:
            var numberSlice = try! local.readCRLFTerminatedSlice2()!
            let numberString = numberSlice.readString(length: numberSlice.readableBytes)!
            let number = Int64(numberString)!
            return .number(number)

        case .double:
            var numberSlice = try! local.readCRLFTerminatedSlice2()!
            let numberString = numberSlice.readString(length: numberSlice.readableBytes)!
            let number = Double(numberString)!
            return .double(number)

        case .verbatimString:
            var lengthSlice = try! local.readCRLFTerminatedSlice2()!
            let lengthString = lengthSlice.readString(length: lengthSlice.readableBytes)!
            let length = Int(lengthString)!
            return .verbatimString(local.readSlice(length: length)!)

        case .bigNumber:
            let lengthSlice = try! local.readCRLFTerminatedSlice2()!
            return .bigNumber(lengthSlice)
        }
    }

    init?(consuming buffer: inout ByteBuffer) throws {
        try self.init(consuming: &buffer, depth: 0)
    }

    fileprivate init?(consuming buffer: inout ByteBuffer, depth: Int) throws {
        let validated: ByteBuffer?

        switch try buffer.getRESP3TypeIdentifier(at: buffer.readerIndex) {
        case .some(.null):
            validated = try buffer.readRESPNullSlice()

        case .some(.boolean):
            validated = try buffer.readRESPBooleanSlice()

        case .some(.blobString),
             .some(.verbatimString),
             .some(.blobError):
            validated = try buffer.readRESPBlobStringSlice()

        case .some(.simpleString),
             .some(.simpleError):
            validated = try buffer.readRESPSimpleStringSlice()

        case .some(.array),
             .some(.push),
             .some(.set),
             .some(.map),
             .some(.attribute):
            validated = try buffer.readRESPAggregateSlice(depth: depth)

        case .some(.integer):
            validated = try buffer.readRESPIntegerSlice()

        case .some(.double):
            validated = try buffer.readRESPDoubleSlice()

        case .some(.bigNumber):
            validated = try buffer.readRESPBigNumberSlice()

        case .none:
            return nil
        }

        guard let validated = validated else { return nil }
        self.base = validated
    }

    init(validated: ByteBuffer) {
        self.base = validated
    }
}

extension ByteBuffer {
    fileprivate mutating func getRESP3TypeIdentifier(at index: Int) throws -> RESP3TypeIdentifier? {
        guard let int = self.getInteger(at: index, as: UInt8.self) else {
            return nil
        }

        guard let id = RESP3TypeIdentifier(rawValue: int) else {
            throw RESP3ParsingError(code: .invalidLeadingByte, buffer: self)
        }

        return id
    }

    fileprivate mutating func readValidatedRESP3TypeIdentifier() -> RESP3TypeIdentifier {
        let int = self.readInteger(as: UInt8.self)!
        return RESP3TypeIdentifier(rawValue: int)!
    }

    fileprivate mutating func readRESPNullSlice() throws -> ByteBuffer? {
        let markerIndex = self.readerIndex
        let copy = self
        guard let (marker, crlf) = self.readMultipleIntegers(as: (UInt8, UInt16).self) else {
            return nil
        }

        let resp3ID = RESP3TypeIdentifier(rawValue: marker)!
        precondition(resp3ID == .null)

        if crlf == .crlf {
            return copy.getSlice(at: markerIndex, length: 3)!
        }

        throw RESP3ParsingError(code: .invalidData, buffer: copy)
    }

    fileprivate mutating func readRESPBooleanSlice() throws -> ByteBuffer? {
        var copy = self
        guard let resp = self.readInteger(as: UInt32.self) else {
            return nil
        }
        switch resp {
        case .respTrue:
            return copy.readSlice(length: 4)!
        case .respFalse:
            return copy.readSlice(length: 4)!
        default:
            throw RESP3ParsingError(code: .invalidData, buffer: copy)
        }
    }

    fileprivate mutating func readRESPBlobStringSlice() throws -> ByteBuffer? {
        let marker = try self.getRESP3TypeIdentifier(at: self.readerIndex)!
        precondition(marker == .blobString || marker == .verbatimString || marker == .blobError)
        guard var lengthSlice = try self.getCRLFTerminatedSlice(at: self.readerIndex + 1) else {
            return nil
        }
        let lengthLineLength = lengthSlice.readableBytes + 2
        let lengthString = lengthSlice.readString(length: lengthSlice.readableBytes)!
        guard let blobLength = Int(lengthString) else {
            throw RESP3ParsingError(code: .canNotParseInteger, buffer: self)
        }

        let respLength = 1 + lengthLineLength + blobLength + 2

        guard let slice = self.readSlice(length: respLength) else {
            return nil
        }

        // validate that the last two characters are \r\n
        if slice.getInteger(at: slice.readableBytes - 2, as: UInt16.self) != .crlf {
            throw RESP3ParsingError(code: .invalidData, buffer: slice)
        }

        // validate that the fourth character is colon, if we have a verbatim string
        if marker == .verbatimString {
            let colonIndex = 1 + lengthLineLength + 3
            guard slice.readableBytes > colonIndex && slice.readableBytesView[colonIndex] == .colon else {
                throw RESP3ParsingError(code: .missingColonInVerbatimString, buffer: slice)
            }
        }

        return slice
    }

    fileprivate mutating func readRESPSimpleStringSlice() throws -> ByteBuffer? {
        let marker = try self.getRESP3TypeIdentifier(at: self.readerIndex)!
        precondition(marker == .simpleString || marker == .simpleError)
        guard let crIndex = try self.firstCRLFIndex(after: self.readerIndex + 1) else {
            return nil
        }

        return self.readSlice(length: crIndex + 2 - self.readerIndex)
    }

    fileprivate mutating func readRESPAggregateSlice(depth: Int) throws -> ByteBuffer? {
        let marker = try self.getRESP3TypeIdentifier(at: self.readerIndex)!
        guard depth < 1000 else {
            throw RESP3ParsingError(code: .tooDepplyNestedAggregatedTypes, buffer: self)
        }

        let multiplier: Int
        switch marker {
        case .array, .push, .set:
            multiplier = 1
        case .map, .attribute:
            multiplier = 2
        default:
            fatalError()
        }

        guard var lengthSlice = try self.getCRLFTerminatedSlice(at: self.readerIndex + 1) else {
            return nil
        }
        let prefixLength = lengthSlice.readableBytes + 3
        let lengthString = lengthSlice.readString(length: lengthSlice.readableBytes)!
        guard let arrayLength = Int(lengthString) else {
            throw RESP3ParsingError(code: .canNotParseInteger, buffer: self)
        }

        var localCopy = self
        localCopy.moveReaderIndex(forwardBy: prefixLength)

        let elementCount = arrayLength * multiplier

        func iterateChildren(consuming localCopy: inout ByteBuffer, count: Int, depth: Int) throws -> Int? {
            var bodyLength = 0
            for _ in 0..<elementCount {
                guard let new = try RESP3Token(consuming: &localCopy, depth: depth + 1) else {
                    return nil
                }
                bodyLength += new.base.readableBytes
            }
            return bodyLength
        }

        let bodyLength: Int?

        if depth > 0 {
            bodyLength = try iterateChildren(consuming: &localCopy, count: elementCount, depth: depth)
        } else {
            do {
                bodyLength = try iterateChildren(consuming: &localCopy, count: elementCount, depth: depth)
            } catch var error as RESP3ParsingError {
                error.buffer = self
                throw error
            }
        }

        guard let bodyLength = bodyLength else { return nil }

        return self.readSlice(length: prefixLength + bodyLength)
    }

    fileprivate mutating func readRESPIntegerSlice() throws -> ByteBuffer? {
        let marker = try self.getRESP3TypeIdentifier(at: self.readerIndex)!
        precondition(marker == .integer)

        guard var slice = try self.getCRLFTerminatedSlice(at: self.readerIndex + 1) else {
            return nil
        }

        let lineLength = slice.readableBytes + 3
        let string = slice.readString(length: slice.readableBytes)!
        if Int64(string) == nil {
            throw RESP3ParsingError(code: .canNotParseInteger, buffer: self)
        }

        return self.readSlice(length: lineLength)!
    }

    fileprivate mutating func readRESPDoubleSlice() throws -> ByteBuffer? {
        let marker = try self.getRESP3TypeIdentifier(at: self.readerIndex)!
        precondition(marker == .double)

        guard var slice = try self.getCRLFTerminatedSlice(at: self.readerIndex + 1) else {
            return nil
        }

        let lineLength = slice.readableBytes + 3
        let string = slice.readString(length: slice.readableBytes)!
        if Double(string) == nil {
            throw RESP3ParsingError(code: .canNotParseDouble, buffer: self)
        }

        return self.readSlice(length: lineLength)!
    }

    fileprivate mutating func readRESPBigNumberSlice() throws -> ByteBuffer? {
        let marker = try self.getRESP3TypeIdentifier(at: self.readerIndex)!
        precondition(marker == .bigNumber)

        guard let slice = try self.getCRLFTerminatedSlice(at: self.readerIndex + 1) else {
            return nil
        }

        var i = 0
        var negative = false
        for digit in slice.readableBytesView {
            defer { i += 1 }
            switch digit {
            case UInt8(ascii: "0")...UInt8(ascii: "9"):
                continue

            case UInt8(ascii: "-") where i == 0:
                negative = true
                continue

            default:
                throw RESP3ParsingError(code: .canNotParseBigNumber, buffer: self)
            }
        }

        if slice.readableBytes == 0 || (negative && slice.readableBytes <= 1) {
            throw RESP3ParsingError(code: .canNotParseBigNumber, buffer: self)
        }

        return self.readSlice(length: slice.readableBytes + 3)!
    }

    fileprivate mutating func readCRLFTerminatedSlice2() throws -> ByteBuffer? {
        guard let slice = try self.getCRLFTerminatedSlice(at: self.readerIndex) else {
            return nil
        }

        self.moveReaderIndex(forwardBy: slice.readableBytes + 2)
        return slice
    }

    private func getCRLFTerminatedSlice(at index: Int) throws -> ByteBuffer? {
        guard let crIndex = try self.firstCRLFIndex(after: index) else {
            return nil
        }

        return self.getSlice(at: index, length: crIndex - index)!
    }

    private func firstCRLFIndex(after index: Int) throws -> Int? {
        if self.readableBytesView.isEmpty { return nil }
        guard let crIndex = self.readableBytesView[index...].firstIndex(where: { $0 == .carriageReturn }) else {
            return nil
        }

        guard crIndex + 1 < self.readableBytesView.endIndex else {
            return nil
        }

        guard self.getInteger(at: crIndex + 1, as: UInt8.self)! == .newline else {
            throw RESP3ParsingError(code: .invalidData, buffer: self)
        }

        return crIndex
    }
}

extension UInt16 {
    fileprivate static let crlf: UInt16 = {
        var value: UInt16 = 0
        let cr = UInt8.carriageReturn
        value += UInt16(UInt8.carriageReturn) << 8
        value += UInt16(UInt8.newline)
        return value
    }()
}

extension UInt32 {
    fileprivate static let respTrue: UInt32 = {
        var value: UInt32 = 0
        value += UInt32(UInt8.pound) << 24
        value += UInt32(UInt8.t) << 16
        value += UInt32(UInt8.carriageReturn) << 8
        value += UInt32(UInt8.newline)
        return value
    }()

    fileprivate static let respFalse: UInt32 = {
        var value: UInt32 = 0
        value += UInt32(UInt8.pound) << 24
        value += UInt32(UInt8.f) << 16
        value += UInt32(UInt8.carriageReturn) << 8
        value += UInt32(UInt8.newline)
        return value
    }()
}

struct RESP3TokenDecoder: NIOSingleStepByteToMessageDecoder {
    typealias InboundOut = RESP3Token

    func decode(buffer: inout ByteBuffer) throws -> RESP3Token? {
        try RESP3Token(consuming: &buffer)
    }

    func decodeLast(buffer: inout ByteBuffer, seenEOF _: Bool) throws -> RESP3Token? {
        try self.decode(buffer: &buffer)
    }
}
