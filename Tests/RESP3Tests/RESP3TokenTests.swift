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
import NIOTestUtils
@testable import RESP3
import XCTest

final class RESP3TokenTests: XCTestCase {

    func testRESPNullToken() {
        let input = ByteBuffer(string: "_\r\n")
        let respNull = RESP3Token(validated: input)

        XCTAssertNoThrow(
            try ByteToMessageDecoderVerifier.verifyDecoder(
                inputOutputPairs: [(input, [respNull])],
                decoderFactory: { RESP3TokenDecoder() }
            )
        )

        XCTAssertEqual(respNull.value, .null)
    }

    func testRESPBoolTrue() {
        let inputTrue = ByteBuffer(string: "#t\r\n")
        let inputFalse = ByteBuffer(string: "#f\r\n")
        let respTrue = RESP3Token(validated: inputTrue)
        let respFalse = RESP3Token(validated: inputFalse)

        XCTAssertNoThrow(
            try ByteToMessageDecoderVerifier.verifyDecoder(
                inputOutputPairs: [
                    (inputTrue, [respTrue]),
                    (inputFalse, [respFalse]),
                ],
                decoderFactory: { RESP3TokenDecoder() }
            )
        )

        XCTAssertEqual(respTrue.value, .boolean(true))
        XCTAssertEqual(respFalse.value, .boolean(false))
    }

    func testBlobString() {
        let input = ByteBuffer(string: "$12\r\naaaabbbbcccc\r\n")
        let respString = RESP3Token(validated: input)

        XCTAssertNoThrow(
            try ByteToMessageDecoderVerifier.verifyDecoder(
                inputOutputPairs: [
                    (input, [respString]),
                ],
                decoderFactory: { RESP3TokenDecoder() }
            )
        )

        XCTAssertEqual(respString.value, .blobString(ByteBuffer(string: "aaaabbbbcccc")))
    }

    func testVerbatimString() {
        let input = ByteBuffer(string: "=16\r\ntxt:aaaabbbbcccc\r\n")
        let respString = RESP3Token(validated: input)

        XCTAssertNoThrow(
            try ByteToMessageDecoderVerifier.verifyDecoder(
                inputOutputPairs: [
                    (input, [respString]),
                ],
                decoderFactory: { RESP3TokenDecoder() }
            )
        )

//        XCTAssertEqual(respString.value, .blobString(ByteBuffer(string: "aaaabbbbcccc")))
    }


    func testSimpleString() {
        let inputString = ByteBuffer(string: "+aaaabbbbcccc\r\n")
        let respString = RESP3Token(validated: inputString)
        let inputError = ByteBuffer(string: "-eeeeffffgggg\r\n")
        let respError = RESP3Token(validated: inputError)

        XCTAssertNoThrow(
            try ByteToMessageDecoderVerifier.verifyDecoder(
                inputOutputPairs: [
                    (inputString, [respString]),
                    (inputError, [respError]),
                ],
                decoderFactory: { RESP3TokenDecoder() }
            )
        )

        XCTAssertEqual(respString.value, .simpleString(ByteBuffer(string: "aaaabbbbcccc")))
        XCTAssertEqual(respError.value, .simpleError(ByteBuffer(string: "eeeeffffgggg")))
    }

    func testArray() {
        let emptyArrayInput = ByteBuffer(string: "*0\r\n")
        let respEmptyArray = RESP3Token(validated: emptyArrayInput)

        let simpleStringArray1Input = ByteBuffer(string: "*1\r\n+aaaabbbbcccc\r\n")
        let respSimpleStringArray1 = RESP3Token(validated: simpleStringArray1Input)

        let simpleStringArray2Input = ByteBuffer(string: "*2\r\n+aaaa\r\n+bbbb\r\n")
        let respSimpleStringArray2 = RESP3Token(validated: simpleStringArray2Input)

        let simpleStringArray3Input = ByteBuffer(string: "*3\r\n*0\r\n+a\r\n-b\r\n")
        let respSimpleStringArray3 = RESP3Token(validated: simpleStringArray3Input)

        let simpleStringPush3Input = ByteBuffer(string: ">3\r\n*0\r\n+a\r\n-b\r\n")
        let respSimpleStringPush3 = RESP3Token(validated: simpleStringPush3Input)

        let simpleStringSet3Input = ByteBuffer(string: "~3\r\n*0\r\n+a\r\n#t\r\n")
        let respSimpleStringSet3 = RESP3Token(validated: simpleStringSet3Input)

        XCTAssertNoThrow(
            try ByteToMessageDecoderVerifier.verifyDecoder(
                inputOutputPairs: [
                    (emptyArrayInput, [respEmptyArray]),
                    (simpleStringArray1Input, [respSimpleStringArray1]),
                    (simpleStringArray2Input, [respSimpleStringArray2]),
                    (simpleStringArray3Input, [respSimpleStringArray3]),
                    (simpleStringPush3Input, [respSimpleStringPush3]),
                    (simpleStringSet3Input, [respSimpleStringSet3]),
                ],
                decoderFactory: { RESP3TokenDecoder() }
            )
        )

        XCTAssertEqual(respEmptyArray.value, .array(.init(count: 0, buffer: .init())))
        XCTAssertEqual(respSimpleStringArray1.value, .array(.init(count: 1, buffer: .init(string: "+aaaabbbbcccc\r\n"))))
        XCTAssertEqual(respSimpleStringArray2.value, .array(.init(count: 2, buffer: .init(string: "+aaaa\r\n+bbbb\r\n"))))
        XCTAssertEqual(respSimpleStringArray3.value, .array(.init(count: 3, buffer: .init(string: "*0\r\n+a\r\n-b\r\n"))))
        XCTAssertEqual(respSimpleStringPush3.value, .push(.init(count: 3, buffer: .init(string: "*0\r\n+a\r\n-b\r\n"))))
        XCTAssertEqual(respSimpleStringSet3.value, .set(.init(count: 3, buffer: .init(string: "*0\r\n+a\r\n#t\r\n"))))

        XCTAssertEqual(respEmptyArray.testArray, [])
        XCTAssertEqual(respSimpleStringArray1.testArray, [.simpleString(.init(string: "aaaabbbbcccc"))])
        XCTAssertEqual(respSimpleStringArray2.testArray, [.simpleString(.init(string: "aaaa")), .simpleString(.init(string: "bbbb"))])
        XCTAssertEqual(respSimpleStringArray3.testArray, [.array(.init(count: 0, buffer: .init())), .simpleString(.init(string: "a")), .simpleError(.init(string: "b"))])
        XCTAssertEqual(respSimpleStringPush3.testArray, [.array(.init(count: 0, buffer: .init())), .simpleString(.init(string: "a")), .simpleError(.init(string: "b"))])
        XCTAssertEqual(respSimpleStringSet3.testArray, [.array(.init(count: 0, buffer: .init())), .simpleString(.init(string: "a")), .boolean(true)])
    }

    func testMap() {
        let emptyMapInput = ByteBuffer(string: "%0\r\n")
        let respEmptyMap = RESP3Token(validated: emptyMapInput)

        let simpleStringMap1Input = ByteBuffer(string: "%1\r\n+aaaa\r\n+bbbb\r\n")
        let respSimpleStringMap1 = RESP3Token(validated: simpleStringMap1Input)

        let simpleStringAttributes1Input = ByteBuffer(string: "|1\r\n+aaaa\r\n#f\r\n")
        let respSimpleStringAttributes1 = RESP3Token(validated: simpleStringAttributes1Input)

        XCTAssertNoThrow(
            try ByteToMessageDecoderVerifier.verifyDecoder(
                inputOutputPairs: [
                    (emptyMapInput, [respEmptyMap]),
                    (simpleStringMap1Input, [respSimpleStringMap1]),
                    (simpleStringAttributes1Input, [respSimpleStringAttributes1]),
                ],
                decoderFactory: { RESP3TokenDecoder() }
            )
        )

        XCTAssertEqual(respEmptyMap.value, .map(.init(count: 0, buffer: .init())))
        XCTAssertEqual(respSimpleStringMap1.value, .map(.init(count: 1, buffer: .init(string: "+aaaa\r\n+bbbb\r\n"))))
        XCTAssertEqual(respSimpleStringAttributes1.value, .attribute(.init(count: 1, buffer: .init(string: "+aaaa\r\n#f\r\n"))))

        XCTAssertEqual(respEmptyMap.testDict, [:])
        XCTAssertEqual(respSimpleStringMap1.testDict, [.simpleString(.init(string: "aaaa")): .simpleString(.init(string: "bbbb"))])
        XCTAssertEqual(respSimpleStringAttributes1.testDict, [.simpleString(.init(string: "aaaa")): .boolean(false)])
    }

}

extension RESP3Token {

    var testArray: [RESP3Token.Value]? {
        switch self.value {
        case .array(let array), .push(let array), .set(let array):
            return [RESP3Token.Value](array.map { $0.value })
        default:
            return nil
        }
    }

    var testDict: [RESP3Token.Value: RESP3Token.Value]? {
        switch self.value {
        case .map(let values), .attribute(let values):
            var result = [RESP3Token.Value: RESP3Token.Value]()
            result.reserveCapacity(values.count)
            for (key, value) in values {
                result[key.value] = value.value
            }
            return result
        default:
            return nil
        }
    }
}
