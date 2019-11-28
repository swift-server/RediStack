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

@testable import RediStack
import RediStackTestUtils
import XCTest

struct LuaTestScripts {

    static let multiSet = RedisScript(scriptSource: """
        local resultIndex = 1
        local result = {}
        for i,k in ipairs(KEYS) do
            if ARGV[i] ~= nil then
                result[resultIndex] = redis.call('SET', k, ARGV[i])
                resultIndex = resultIndex + 1
            end
        end
        return result
    """)

    static let multiGet = RedisScript(scriptSource: """
        local resultIndex = 1
        local result = {}
        for i,k in ipairs(KEYS) do
            result[resultIndex] = redis.call('GET', k)
            resultIndex = resultIndex + 1
        end
        return result
    """)

    static let sayHello = RedisScript(scriptSource: """
        return "hello!"
    """)

}

final class ScriptingCommandsTests: RediStackIntegrationTestCase {

    override func setUp() {
        super.setUp()
        do {
            _ = try self.connection.send(command: "SCRIPT", with: [.init(bulk: "FLUSH")]).wait()
        } catch {
            XCTFail("Failed to create RedisConnection! \(error)")
        }
    }

    func test_multiSetScript() throws {
        let keys = ["one", "two", "three"]
        let values = ["1", "2", "string3"]

        let result = try connection.evalScript(LuaTestScripts.multiSet!, keys: keys, args: values).wait()

        XCTAssertEqual(
            result.array!.map({ $0.string }),
            ["OK", "OK", "OK"]
        )
    }

    func test_multiGetScript() throws {
        let keys = ["one", "two", "three"]
        let values = ["1", "2", "string3"]
        let merged = Dictionary(uniqueKeysWithValues: zip(keys, values))

        try connection.mset(merged).wait()

        let result = try connection.evalScript(LuaTestScripts.multiGet!, keys: keys).wait()

        XCTAssertEqual(
            result.array!.map({ $0.string }),
            ["1", "2", "string3"]
        )

        XCTAssertEqual(
            result.array![0].int,
            1
        )
    }

    func test_scriptLoadedAfterFirstUse() throws {
        let keys = ["one", "two", "three"]
        let values = ["1", "2", "string3"]

        let scriptExistsBefore = try connection.send(command: "SCRIPT", with: [.init(bulk: "EXISTS"), .init(bulk: LuaTestScripts.sayHello!.hash)]).wait()
        print(scriptExistsBefore)

        XCTAssertEqual(scriptExistsBefore.array?.first?.int, 0)

        let resultFromUncachedScript = try connection.evalScript(LuaTestScripts.sayHello!, keys: keys, args: values).wait()

        XCTAssertEqual(
            resultFromUncachedScript.string,
            "hello!"
         )

        let scriptExistsAfter = try connection.send(command: "SCRIPT", with: [.init(bulk: "EXISTS"), .init(bulk: LuaTestScripts.sayHello!.hash)]).wait()
        XCTAssertEqual(scriptExistsAfter.array?.first?.int, 1)

        let resultFromCachedScript = try connection.evalScript(LuaTestScripts.sayHello!, keys: keys, args: values).wait()

        XCTAssertEqual(
            resultFromCachedScript.string,
            "hello!"
        )
    }

    func test_scriptLoad() throws {
        let loadResultSha1 = try connection.scriptLoad(LuaTestScripts.sayHello!.scriptSource).wait()

        // Check that the redis-calculated sha1 matches
        // the client-calculated sha1
        XCTAssertEqual(
            loadResultSha1,
            LuaTestScripts.sayHello?.hash
        )
    }

    func test_scriptExistsSingle() throws {
        let keys = ["one", "two", "three"]
        let values = ["1", "2", "string3"]

        let scriptExistsBefore = try connection.scriptExists(LuaTestScripts.sayHello!.hash).wait()

        XCTAssertEqual(scriptExistsBefore, false)

        let resultFromUncachedScript = try connection.evalScript(LuaTestScripts.sayHello!, keys: keys, args: values).wait()

        XCTAssertEqual(
            resultFromUncachedScript.string,
            "hello!"
         )

        let scriptExistsAfter = try connection.scriptExists(LuaTestScripts.sayHello!.hash).wait()
        XCTAssertEqual(scriptExistsAfter, true)

        let resultFromCachedScript = try connection.evalScript(LuaTestScripts.sayHello!, keys: keys, args: values).wait()

        XCTAssertEqual(
            resultFromCachedScript.string,
            "hello!"
        )
    }

    func test_scriptExistsMultiple() throws {
        let scriptExistsBefore = try connection.scriptExists([
            LuaTestScripts.sayHello!.hash,
            LuaTestScripts.multiGet!.hash,
            LuaTestScripts.multiSet!.hash
        ]).wait()

        XCTAssertEqual(scriptExistsBefore, [false, false, false])

        _ = try connection.scriptLoad(LuaTestScripts.sayHello!.scriptSource).wait()
        _ = try connection.scriptLoad(LuaTestScripts.multiGet!.scriptSource).wait()

        let scriptExistsAfter = try connection.scriptExists([
            LuaTestScripts.sayHello!.hash,
            LuaTestScripts.multiGet!.hash,
            LuaTestScripts.multiSet!.hash
        ]).wait()

        XCTAssertEqual(scriptExistsAfter, [true, true, false])

    }

}
