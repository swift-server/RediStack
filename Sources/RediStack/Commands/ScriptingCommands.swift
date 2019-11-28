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

import NIO

// MARK: Script struct

///
/// Rather than storing your scripts as a simple String, using the RedisScript
/// struct will compute the correct sha1 hash only once. Redis uses this hash
/// to invoke your script without sending the full script source code every time.
///
public struct RedisScript: CustomStringConvertible {

    /// The Lua source code of redis script
    public let scriptSource: String

    /// The sha1 hash of the script, used by redis to reference
    /// your cached script. This will be calculated when you initialize
    /// and instance of RedisScript.
    public let hash: String

    init?(scriptSource: String) {
        self.scriptSource = scriptSource
        guard let hash = scriptSource.sha1 else {
            return nil
        }
        self.hash = hash
    }

    public var description: String {
        return """
        hash: \(self.hash)
        script:
        \(self.scriptSource)
        """
    }
}

// MARK: General

extension RedisClient {

    /// Evaluate a script provided by a RedisScript instance containing the Lua source code
    ///
    /// This command will first attempt to evaluate your script from a cached sha1 hash. If this fails,
    /// it will proceed with the regular EVAL command, caching your script for future invocations.
    ///
    /// See [https://redis.io/commands/eval](https://redis.io/commands/eval)
    /// and [https://redis.io/commands/evalsha](https://redis.io/commands/evalsha)
    /// - Parameters:
    ///     - script: An instance of RedisScript initialized with the Lua source code. Maintaining a static set of RedisScript instances in your application is recommended - this way the sha1 hash will be calculated only once. 
    ///     - keys: The names of keys that will be passed to this script.
    ///     - args: The additional arguments that will be passed to this script.
    /// - Returns: The value of the hash field, or `nil` if either the key or field does not exist.
    @inlinable
    public func evalScript(_ script: RedisScript, keys: [String] = [], args: [String] = []) -> EventLoopFuture<RESPValue> {
        return evalScript(script.scriptSource, sha1: script.hash, keys: keys, args: args)
    }

    /// Evaluate a script from a String containing the Lua source code.
    ///
    /// This command will first attempt to evaluate your script from a cached sha1 hash. If this fails,
    /// it will proceed with the regular EVAL command, caching your script for future invocations.
    ///
    /// See [https://redis.io/commands/eval](https://redis.io/commands/eval)
    /// and [https://redis.io/commands/evalsha](https://redis.io/commands/evalsha)
    /// - Parameters:
    ///     - scriptSource: The Lua script source code as a String.
    ///     - sha1: Optional sha1 of this script - will be calculated on every invocation if omitted (use the RedisScript struct to avoid this, or calculate and cache the sha1 elsewhere in your application).
    ///     - keys: The names of keys that will be passed to this script.
    ///     - args: The additional arguments that will be passed to this script.
    /// - Returns: The value of the hash field, or `nil` if either the key or field does not exist.
    @inlinable
    public func evalScript(_ scriptSource: String, sha1: String? = nil, keys: [String] = [], args: [String] = []) -> EventLoopFuture<RESPValue> {

        guard let hash = sha1 ?? scriptSource.sha1 else {
            // Unsure of the correct error response, in this case,
            // however, this guard should never be triggered.
            let error = RedisClientError.assertionFailure(message: "Could not calculate sha1 hash for this script")
            return self.eventLoop.makeFailedFuture(error)
        }

        let keysArgs: [RESPValue] = (keys + args).map({ RESPValue(bulk: $0) })
        let args: [RESPValue] = [
            .init(bulk: "\(keys.count)")
        ] + keysArgs

        let scriptHashArg = hash.convertedToRESPValue()
        let evalShaArgs = [scriptHashArg] + args
        return send(command: "EVALSHA", with: evalShaArgs)
            .flatMapError { error in
                // This script is not stored on the server:
                // we will proceed with regular EVAL.
                guard
                    let redisError = error as? RedisError,
                    redisError.message.contains("NOSCRIPT") else {
                    return self.eventLoop.makeFailedFuture(error)
                }
                let scriptSourceArg = scriptSource.convertedToRESPValue()
                let evalArgs = [scriptSourceArg] + args
                return self.send(command: "EVAL", with: evalArgs)

        }.convertFromRESPValue()
    }

    /// Load a script into the redis cache and return the corresponding sha1 hash.
    ///
    /// See [https://redis.io/commands/script-load](https://redis.io/commands/script-load)
    /// - Parameter scriptSource: The Lua script source code as a String.
    /// - Returns: The sha1 String for this script.
    @inlinable
    public func scriptLoad(_ scriptSource: String) -> EventLoopFuture<String> {
        let args: [RESPValue] = [
            .init(bulk: "LOAD"),
            .init(bulk: scriptSource)
        ]
        return send(command: "SCRIPT", with: args)
            .convertFromRESPValue(to: String.self)
    }

    /// Checks if a script with the given sha1 hash has been loaded.
    ///
    /// See [https://redis.io/commands/script-exists](https://redis.io/commands/script-exists)
    /// - Parameter sha1: A single sha1 hash to check.
    /// - Returns: `true` if the script has been loaded, `false` if it has not.
    @inlinable
    public func scriptExists(_ sha1: String) -> EventLoopFuture<Bool> {
        let args: [RESPValue] = [
            .init(bulk: "EXISTS"),
            .init(bulk: sha1)
        ]
        return send(command: "SCRIPT", with: args)
            .convertFromRESPValue(to: Array<Int>.self)
            .map { return $0[0] == 1 }
    }

    /// Checks if scripts with the given sha1 hashes have been loaded.
    ///
    /// See [https://redis.io/commands/script-exists](https://redis.io/commands/script-exists)
    /// - Parameter sha1: An array of sha1 hashes to check.
    /// - Returns: An array matching the order of sha1 hashes provided, with values of`true` if the script has been loaded, `false` if it has not.
    @inlinable
    public func scriptExists(_ sha1: [String]) -> EventLoopFuture<[Bool]> {
        let args: [RESPValue] = [
            .init(bulk: "EXISTS")
        ] + sha1.map({ RESPValue(bulk: $0) })
        return send(command: "SCRIPT", with: args)
            .convertFromRESPValue(to: Array<Int>.self)
            .map { $0.map({ $0 == 1 }) }
    }

    /// Flush all scripts the redis script cache.
    ///
    /// Lua scripts take up a relatively small amount of memory in redis. This command is useful for development and
    /// testing, but the redis documentation advises that you should not need to routinely flush scripts in your application.
    ///
    /// See [https://redis.io/commands/script-flush](https://redis.io/commands/script-flush)
    /// - Returns: An `EventLoopFuture` that resolves if the operation was successful.
    @inlinable
    public func scriptFlush() -> EventLoopFuture<Void> {
        let args: [RESPValue] = [
            .init(bulk: "FLUSH"),
        ]
        return send(command: "SCRIPT", with: args)
            .map { _ in () }
    }

}
