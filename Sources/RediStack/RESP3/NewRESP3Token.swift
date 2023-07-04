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

struct NewRESP3Token: Hashable, Sendable {

    struct BlobError: Error, Hashable {

    }

    struct SimpleError: Error, Hashable {

    }

    struct VerbatimString: Hashable, Sendable {
        var marker: String
        var body: ByteBuffer
    }

    struct Array: Sequence, Sendable, Hashable {
        typealias Element = NewRESP3Token

        let count: Int
        let buffer: ByteBuffer

        func makeIterator() -> Iterator {
            Iterator(buffer: self.buffer)
        }
        
        struct Iterator: IteratorProtocol {
            typealias Element = NewRESP3Token

            var buffer: ByteBuffer
            
            mutating func next() -> NewRESP3Token? {
                return try! NewRESP3Token(consuming: &self.buffer)
            }
        }
    }

    struct Map: Sequence, Sendable, Hashable {
        typealias Element = (key: NewRESP3Token, value: NewRESP3Token)

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
            typealias Element = (key: NewRESP3Token, value: NewRESP3Token)

            var underlying: Array.Iterator

            mutating func next() -> (key: NewRESP3Token, value: NewRESP3Token)? {
                guard let key = self.underlying.next() else {
                    return nil
                }

                let value = self.underlying.next()!
                return (key, value)
            }
        }
    }

    enum Value: Hashable {
        case blobString(ByteBuffer)
        case simpleString(ByteBuffer)
        case simpleError(ByteBuffer)
//        case number(Int64)
        case null
//        case double(Double)
        case boolean(Bool)
//        case blobError(BlobError)
//        case verbatimString(VerbatimString)
//        case bigNumber(String)
//
        case array(Array)
        case attribute(Map)
        case map(Map)
        case set(Array)
        case push(Array)
    }

    let base: ByteBuffer

    var value: Value {
        var local = self.base

        switch local.readInteger(as: UInt8.self)! {
        case .underscore:
            return .null

        case .pound:
            return .boolean(local.readInteger(as: UInt8.self)! == .t)

        case .dollar:
            var lengthSlice = try! local.readCRLFTerminatedSlice2()!
            let lengthString = lengthSlice.readString(length: lengthSlice.readableBytes)!
            let length = Int(lengthString)!
            return .blobString(local.readSlice(length: length)!)

        case .plus:
            let slice = try! local.readCRLFTerminatedSlice2()!
            return .simpleString(slice)

        case .hyphen:
            let slice = try! local.readCRLFTerminatedSlice2()!
            return .simpleError(slice)

        case .asterisk:
            var countSlice = try! local.readCRLFTerminatedSlice2()!
            let countString = countSlice.readString(length: countSlice.readableBytes)!
            let count = Int(countString)!
            return .array(.init(count: count, buffer: local))

        case .rightAngledBracket:
            var countSlice = try! local.readCRLFTerminatedSlice2()!
            let countString = countSlice.readString(length: countSlice.readableBytes)!
            let count = Int(countString)!
            return .push(.init(count: count, buffer: local))

        case .tilde:
            var countSlice = try! local.readCRLFTerminatedSlice2()!
            let countString = countSlice.readString(length: countSlice.readableBytes)!
            let count = Int(countString)!
            return .set(.init(count: count, buffer: local))

        case .pipe:
            var countSlice = try! local.readCRLFTerminatedSlice2()!
            let countString = countSlice.readString(length: countSlice.readableBytes)!
            let count = Int(countString)!
            return .attribute(.init(count: count, buffer: local))

        case .percent:
            var countSlice = try! local.readCRLFTerminatedSlice2()!
            let countString = countSlice.readString(length: countSlice.readableBytes)!
            let count = Int(countString)!
            return .map(.init(count: count, buffer: local))

        default:
            fatalError()
        }
    }

    init?(consuming buffer: inout ByteBuffer) throws {
        let validated: ByteBuffer?

        switch buffer.getInteger(at: buffer.readerIndex, as: UInt8.self) {
        case .some(.underscore):
            validated = try buffer.readRESPNullSlice()

        case .some(.pound):
            validated = try buffer.readRESPBooleanSlice()

        case .some(.dollar), .some(.equals):
            validated = try buffer.readRESPBlobStringSlice()

        case .some(.plus), .some(.hyphen):
            validated = try buffer.readRESPSimpleStringSlice()

        case .some(.asterisk), .some(.rightAngledBracket), .some(.tilde), .some(.pipe), .some(.percent):
            validated = try buffer.readRESPAggregateSlice()

        case .some(let value):
            throw RESP3Error.invalidType(value)

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
    fileprivate mutating func readCRLF() throws {
        guard let (first, second) = self.readMultipleIntegers(as: (UInt8, UInt8).self) else {
            throw RESP3Error.missingData
        }

        if first == .carriageReturn && second == .newline {
            return
        }

        throw RESP3Error.missingCRLF
    }

    fileprivate mutating func readRESPNullSlice() throws -> ByteBuffer? {
        let markerIndex = self.readerIndex
        let copy = self
        guard let (marker, cr, lf) = self.readMultipleIntegers(as: (UInt8, UInt8, UInt8).self) else {
            return nil
        }
        precondition(marker == .underscore)

        if cr == .carriageReturn && lf == .newline {
            return copy.getSlice(at: markerIndex, length: 3)!
        }

        throw RESP3Error.missingCRLF
    }

    fileprivate mutating func readRESPBooleanSlice() throws -> ByteBuffer? {
        var copy = self
        guard let (marker, value, cr, lf) = self.readMultipleIntegers(as: (UInt8, UInt8, UInt8, UInt8).self) else {
            return nil
        }
        precondition(marker == .pound)

        switch value {
        case .f, .t:
            break
        default:
            throw RESP3Error.dataMalformed
        }

        if cr == .carriageReturn && lf == .newline {
            return copy.readSlice(length: 4)!
        }

        throw RESP3Error.missingCRLF
    }

    fileprivate mutating func readRESPBlobStringSlice() throws -> ByteBuffer? {
        let marker = self.getInteger(at: self.readerIndex, as: UInt8.self)!
        precondition(marker == .dollar || marker == .equals)
        guard var lengthSlice = try self.getCRLFTerminatedSlice(at: self.readerIndex + 1) else {
            return nil
        }
        let lengthLineLength = lengthSlice.readableBytes + 2
        let lengthString = lengthSlice.readString(length: lengthSlice.readableBytes)!
        guard let blobLength = Int(lengthString) else {
            throw RESP3Error.dataMalformed
        }

        let respLength = 1 + lengthLineLength + blobLength + 2

        guard let slice = self.readSlice(length: respLength) else {
            return nil
        }

        // validate that the last two characters are \r\n
        if slice.getInteger(at: slice.readableBytes - 2, as: UInt16.self) != .crlf {
            throw RESP3Error.dataMalformed
        }

        // validate that the fourth character is colon, if we have a verbatim string
        if marker == .equals {
            let colonIndex = 1 + lengthLineLength + 3
            guard slice.readableBytes > colonIndex && slice.readableBytesView[colonIndex] == .colon else {
                throw RESP3Error.dataMalformed
            }
        }

        return slice
    }

    fileprivate mutating func readRESPSimpleStringSlice() throws -> ByteBuffer? {
        let marker = self.getInteger(at: self.readerIndex, as: UInt8.self)!
        precondition(marker == UInt8.plus || marker == UInt8.hyphen)
        guard let crIndex = try self.firstCRLFIndex(after: self.readerIndex + 1) else {
            return nil
        }

        return self.readSlice(length: crIndex + 2 - self.readerIndex)
    }

    fileprivate mutating func readRESPAggregateSlice() throws -> ByteBuffer? {
        let marker = self.getInteger(at: self.readerIndex, as: UInt8.self)!
        let multiplier: Int
        switch marker {
        case .asterisk, .rightAngledBracket, .tilde:
            multiplier = 1
        case .pipe, .percent:
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
            throw RESP3Error.dataMalformed
        }

        var localCopy = self
        localCopy.moveReaderIndex(forwardBy: prefixLength)

        var bodyLength = 0

        let elementCount = arrayLength * multiplier

        for _ in 0..<elementCount {
            guard let new = try NewRESP3Token(consuming: &localCopy) else {
                return nil
            }
            bodyLength += new.base.readableBytes
        }

        return self.readSlice(length: prefixLength + bodyLength)
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
            throw RESP3Error.dataMalformed
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

struct RESP3TokenDecoder: NIOSingleStepByteToMessageDecoder {
    
    typealias InboundOut = NewRESP3Token

    func decode(buffer: inout ByteBuffer) throws -> NewRESP3Token? {
        try NewRESP3Token(consuming: &buffer)
    }

    func decodeLast(buffer: inout ByteBuffer, seenEOF: Bool) throws -> NewRESP3Token? {
        try self.decode(buffer: &buffer)
    }
}
