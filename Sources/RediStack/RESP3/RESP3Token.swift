import NIO

enum RESP3Error: Error {
    case unexpectedEndOfData
    case missingCRLF
    case dataMalformed
    case invalidType(UInt8)
}

struct RESP3Token {
    private enum _TypeIdentifier {
        static let integer = UInt8.colon
        static let double = UInt8.comma
        static let simpleString = UInt8.plus
        static let simpleError = UInt8.min
        static let blobString = UInt8.dollar
        static let blobError = UInt8.exclamationMark
        static let verbatimString = UInt8.equals
        static let boolean = UInt8.pound
        static let null = UInt8.underscore
        static let bigNumber = UInt8.leftRoundBracket
        static let array = UInt8.asterisk
        static let map = UInt8.percent
        static let set = UInt8.tilde
        static let attribute = UInt8.pipe
        static let push = UInt8.rightAngledBracket
    }

    enum TypeIdentifier {
        case integer
        case double
        case simpleString
        case simpleError
        case blobString
        case blobError
        case verbatimString
        case boolean
        case null
        case bigNumber

        case array
        case map
        case set
        case attribute
        case push
    }

    internal enum Value {
        case blobString(ByteBuffer)
        case null
    }

    let type: TypeIdentifier
    private var buffer: ByteBuffer

    static func validate(consuming buffer: inout ByteBuffer) throws -> RESP3Token {
        let endIndex: Int
        let type: TypeIdentifier

        do {
            // Scope a copy of `buffer` to the validation logic
            // That way we cannot accidentally write code that reads
            // from the wrong buffer
            var buffer = buffer.slice()

            guard let typeIdentifier = buffer.readInteger(as: UInt8.self) else {
                throw RESP3Error.unexpectedEndOfData
            }

            switch typeIdentifier {
            case _TypeIdentifier.null:
                try buffer.consumeCRLF()
                type = .null
            case _TypeIdentifier.double:
                guard
                    let string = buffer.readCRLFTerminatedString(),
                    Double(string) != nil
                else {
                    throw RESP3Error.dataMalformed
                }

                type = .double
            case _TypeIdentifier.integer:
                guard
                    let string = buffer.readCRLFTerminatedString(),
                    Int64(string) != nil
                else {
                    throw RESP3Error.dataMalformed
                }

                type = .integer
            case _TypeIdentifier.bigNumber:
                guard let bignum = buffer.readCRLFTerminatedSlice() else {
                    throw RESP3Error.dataMalformed
                }

                for byte in bignum.readableBytesView[bignum.readerIndex...]{
                    guard UInt8.zero ... UInt8.nine ~= byte || byte == .min else {
                        throw RESP3Error.dataMalformed
                    }
                }

                type = .bigNumber
            case _TypeIdentifier.simpleString:
                guard let stringPosition = buffer.getCRLFTerminatedStringLength(at: buffer.readerIndex) else {
                    throw RESP3Error.dataMalformed
                }

                // String Start + String Length + CRLF
                buffer.moveReaderIndex(forwardBy: stringPosition.tokenEndIndex)

                type = .simpleString
            case _TypeIdentifier.blobString, _TypeIdentifier.blobError:
                // Length encoded
                guard
                    let length = buffer.readCRLFTerminatedInteger(),
                    buffer.readableBytes >= length
                else {
                    throw RESP3Error.dataMalformed
                }

                // Don't copy, but pass over the String
                buffer.moveReaderIndex(forwardBy: length)
                try buffer.consumeCRLF()

                type = .blobString
            case _TypeIdentifier.verbatimString:
                // Also length encoded, but requies a three character prefix
                // followed by a colon (thus 4)
                let minimumLength = 4

                guard
                    let length = buffer.readCRLFTerminatedInteger(),
                    length >= minimumLength,
                    buffer.readableBytes >= length,
                    let colon = buffer.getInteger(at: buffer.readerIndex + 3, as: UInt8.self),
                    colon == .colon
                else {
                    throw RESP3Error.dataMalformed
                }

                // Don't copy, but pass over the String
                buffer.moveReaderIndex(forwardBy: length)
                try buffer.consumeCRLF()

                type = .verbatimString
            case _TypeIdentifier.boolean:
                switch buffer.readInteger(as: UInt8.self) {
                case UInt8.t, UInt8.f: // true, false respectively
                    try buffer.consumeCRLF()
                default:
                    throw RESP3Error.dataMalformed
                }

                type = .boolean
            case _TypeIdentifier.array:
                guard
                    let count = buffer.readCRLFTerminatedInteger(),
                    count >= 0
                else {
                    throw RESP3Error.dataMalformed
                }

                for _ in 0..<count {
                    _ = try Self.validate(consuming: &buffer)
                }

                type = .array
            case _TypeIdentifier.set:
                guard
                    let count = buffer.readCRLFTerminatedInteger(),
                    count >= 0
                else {
                    throw RESP3Error.dataMalformed
                }

                for _ in 0..<count {
                    _ = try Self.validate(consuming: &buffer)
                }

                type = .set
            case _TypeIdentifier.map:
                try verifyMapType(consuming: &buffer)
                type = .map
            case _TypeIdentifier.push:
                // RESP3 Push is at least 1 string long
                guard
                    let count = buffer.readCRLFTerminatedInteger(),
                    count >= 1
                else {
                    throw RESP3Error.dataMalformed
                }

                let pushType = try Self.validate(consuming: &buffer)
                guard pushType.type == .simpleString else {
                    throw RESP3Error.dataMalformed
                }

                for _ in 1..<count {
                    _ = try Self.validate(consuming: &buffer)
                }

                type = .push
            case _TypeIdentifier.attribute:
                try verifyMapType(consuming: &buffer)
                type = .attribute
            default:
                throw RESP3Error.invalidType(typeIdentifier)
            }

            endIndex = buffer.readerIndex
        }

        let length = endIndex - buffer.readerIndex
        return RESP3Token(type: type, buffer: buffer.readSlice(length: length)!)
    }

    private static func verifyMapType(consuming buffer: inout ByteBuffer) throws {
        guard
            let count = buffer.readCRLFTerminatedInteger(),
            count >= 0
        else {
            throw RESP3Error.dataMalformed
        }

        for _ in 0..<count {
            let key = try Self.validate(consuming: &buffer)
            guard key.type == .simpleString else {
                throw RESP3Error.dataMalformed
            }

            _ = try Self.validate(consuming: &buffer)
        }
    }
}

extension ByteBuffer {
    fileprivate struct CRLFTerminatedStringPosition {
        let tokenStartIndex: Int
        let stringLength: Int
        let stringStartIndex: Int

        var tokenEndIndex: Int {
            stringStartIndex + stringLength + 2
        }
    }

    fileprivate func getCRLFTerminatedStringLength(at index: Int) -> CRLFTerminatedStringPosition? {
        let stringStartIndex = self.readerIndex

        guard stringStartIndex <= index && index < self.writerIndex else {
            return nil
        }

        guard let endIndex = self.readableBytesView[index...].firstIndex(of: .carriageReturn) else {
            return nil
        }

        guard self.getInteger(at: endIndex + 1, as: UInt8.self) == .newline else {
            return nil
        }

        let length = endIndex - index

        return CRLFTerminatedStringPosition(
            tokenStartIndex: index,
            stringLength: length,
            stringStartIndex: stringStartIndex
        )
    }

    fileprivate func isCRLFValidTerminatedString(isValidCharacter: (UInt8) -> Bool) -> Bool {
        guard let stringPosition = self.getCRLFTerminatedStringLength(at: self.readerIndex) else {
            return false
        }

        let stringStartIndex = stringPosition.stringStartIndex
        let stringLength = stringPosition.stringLength

        let string = self.readableBytesView[stringStartIndex ..< stringStartIndex + stringLength]
        for byte in string {
            if !isValidCharacter(byte) {
                return false
            }
        }

        return true
    }

    fileprivate mutating func readCRLFTerminatedSlice() -> ByteBuffer? {
        guard let stringPosition = self.getCRLFTerminatedStringLength(at: self.readerIndex) else {
            return nil
        }

        let result = self.getSlice(at: stringPosition.stringStartIndex, length: stringPosition.stringLength)
        moveReaderIndex(forwardBy: stringPosition.stringLength)
        return result
    }

    fileprivate mutating func readCRLFTerminatedString() -> String? {
        guard let slice = self.readCRLFTerminatedSlice() else {
            return nil
        }

        return slice.getString(at: slice.readerIndex, length: slice.readableBytes)
    }

    fileprivate mutating func readCRLFTerminatedInteger() -> Int? {
        guard let result = readCRLFTerminatedString() else {
            return nil
        }

        return Int(result)
    }


    fileprivate mutating func readCRLFTerminatedDouble() -> Double? {
        guard let result = readCRLFTerminatedString() else {
            return nil
        }

        return Double(result)
    }

    fileprivate mutating func consumeCRLF() throws {
        guard
            readInteger(as: UInt8.self) == .carriageReturn,
            readInteger(as: UInt8.self) == .newline
        else {
            throw RESP3Error.missingCRLF
        }
    }
}
