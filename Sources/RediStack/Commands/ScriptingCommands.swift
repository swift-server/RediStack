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

// MARK: Script Wrapper

/// A helper struct for Lua scripts that can be sent to Redis for execution.
///
/// During initialization, a SHA1 hash will be generated from the script's content to eagerly attempt to use the `EVALSHA` command.
public struct RedisScript {
    /// The Lua source code of this RedisScript.
    public let content: String
    /// The SHA1 hash of the script content.
    ///
    /// This is used by Redis to reference scripts it has already "seen" at least once.
    ///
    /// See [https://redis.io/commands/eval](https://redis.io/commands/eval).
    public let hash: String
    
    /// - Parameter content: The content of the Lua script.
    public init(_ content: String) {
        guard let hash = content.sha1 else {
            preconditionFailure("Failed to create a RedisScript SHA1 hash from a valid string.")
        }
        self.hash = hash
        self.content = content
    }
    
    @usableFromInline
    internal init(content: String, hash: String) {
        self.hash = hash
        self.content = content
    }
}

extension RedisScript: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String
    
    public init(stringLiteral: StringLiteralType) {
        self.init(stringLiteral)
    }
}

extension RedisScript: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String { return self.content }
    
    public var debugDescription: String {
        return """
        hash: \(self.hash)
        script:
        \(self.content)
        """
    }
}

// MARK: Script Eval

//extension RedisClient {
//    @inlinable
//    public func evalScript(_ script: RedisScript) -> EventLoopFuture<RESPValue> {
//        
//    }
//    
//    @inlinable func evalScript(
//        raw: String,
//        hash: String? = nil,
//        keys: [String] = [],
//        args: [String] = []
//    ) -> EventLoopFuture<RESPValue> {
//        
//    }
//
//    /// Evaluate a script provided by a RedisScript instance containing the Lua source code
//    ///
//    /// This command will first attempt to evaluate your script from a cached sha1 hash. If this fails,
//    /// it will proceed with the regular EVAL command, caching your script for future invocations.
//    ///
//    /// See [https://redis.io/commands/eval](https://redis.io/commands/eval)
//    /// and [https://redis.io/commands/evalsha](https://redis.io/commands/evalsha)
//    /// - Parameters:
//    ///     - script: An instance of RedisScript initialized with the Lua source code. Maintaining a static set of RedisScript instances in your application is recommended - this way the sha1 hash will be calculated only once. 
//    ///     - keys: The names of keys that will be passed to this script.
//    ///     - args: The additional arguments that will be passed to this script.
//    /// - Returns: The value of the hash field, or `nil` if either the key or field does not exist.
//    @inlinable
//    public func evalScript(_ script: RedisScript, keys: [String] = [], args: [String] = []) -> EventLoopFuture<RESPValue> {
//        return evalScript(script.scriptSource, sha1: script.hash, keys: keys, args: args)
//    }
//
//    /// Evaluate a script from a String containing the Lua source code.
//    ///
//    /// This command will first attempt to evaluate your script from a cached sha1 hash. If this fails,
//    /// it will proceed with the regular EVAL command, caching your script for future invocations.
//    ///
//    /// See [https://redis.io/commands/eval](https://redis.io/commands/eval)
//    /// and [https://redis.io/commands/evalsha](https://redis.io/commands/evalsha)
//    /// - Parameters:
//    ///     - scriptSource: The Lua script source code as a String.
//    ///     - sha1: Optional sha1 of this script - will be calculated on every invocation if omitted (use the RedisScript struct to avoid this, or calculate and cache the sha1 elsewhere in your application).
//    ///     - keys: The names of keys that will be passed to this script.
//    ///     - args: The additional arguments that will be passed to this script.
//    /// - Returns: The value of the hash field, or `nil` if either the key or field does not exist.
//    @inlinable
//    public func evalScript(_ scriptSource: String, sha1: String? = nil, keys: [String] = [], args: [String] = []) -> EventLoopFuture<RESPValue> {
//
//        guard let hash = sha1 ?? scriptSource.sha1 else {
//            // Unsure of the correct error response, in this case,
//            // however, this guard should never be triggered.
//            let error = RedisClientError.assertionFailure(message: "Could not calculate sha1 hash for this script")
//            return self.eventLoop.makeFailedFuture(error)
//        }
//
//        let keysArgs: [RESPValue] = (keys + args).map({ RESPValue(bulk: $0) })
//        let args: [RESPValue] = [
//            .init(bulk: "\(keys.count)")
//        ] + keysArgs
//
//        let scriptHashArg = hash.convertedToRESPValue()
//        let evalShaArgs = [scriptHashArg] + args
//        return send(command: "EVALSHA", with: evalShaArgs)
//            .flatMapError { error in
//                // This script is not stored on the server:
//                // we will proceed with regular EVAL.
//                guard
//                    let redisError = error as? RedisError,
//                    redisError.message.contains("NOSCRIPT") else {
//                    return self.eventLoop.makeFailedFuture(error)
//                }
//                let scriptSourceArg = scriptSource.convertedToRESPValue()
//                let evalArgs = [scriptSourceArg] + args
//                return self.send(command: "EVAL", with: evalArgs)
//
//        }.convertFromRESPValue()
//    }
//}

// MARK: Script Loading

extension RedisClient {
    /// Sends a raw Lua script to Redis for "preloading" and returns the script as a `RedisScript`.
    ///
    /// See [https://redis.io/commands/script-load](https://redis.io/commands/script-load)
    /// - Parameter scriptSource: The Lua script source code.
    /// - Returns: A `RedisScript` that represents the raw Lua code.
    @inlinable
    public func scriptLoad(_ scriptSource: String) -> EventLoopFuture<RedisScript> {
        return self._scriptLoad(scriptSource)
            .map { hash in return RedisScript(content: scriptSource, hash: hash) }
    }
    
    @usableFromInline
    internal func _scriptLoad(_ content: String) -> EventLoopFuture<String> {
        let args: [RESPValue] = [
            .init(bulk: "LOAD"),
            .init(bulk: content)
        ]
        return send(command: "SCRIPT", with: args)
            .convertFromRESPValue()
    }
}

extension RedisScript {
    /// Loads the script with the provided `RedisClient`.
    ///
    /// See `RedisClient.scriptLoad(_:)`.
    /// - Parameter client: The `RedisClient` to use for executing the command against Redis.
    /// - Returns: A `NIO.EventLoopFuture` that resolves when the script has been loaded.
    public func load(with client: RedisClient) -> EventLoopFuture<Void> {
        #if DEBUG
        return client._scriptLoad(self.content)
            .map { assert($0 == self.hash); return () }
        #else
        return client._scriptLoad(self.content)
            .map { _ in () }
        #endif
    }
}

// MARK: Script Exists

extension RedisClient {
    /// Checks if the provided `RedisScript` has been loaded into the Redis script cache.
    ///
    /// See [https://redis.io/commands/script-exists](https://redis.io/commands/script-exists)
    /// - Parameter script: The `RedisScript` to check for cache existence.
    /// - Returns: `true` if it exists in the Redis script cache, otherwise `false`.
    public func scriptExists(_ script: RedisScript) -> EventLoopFuture<Bool> {
        return self.scriptExists(script.hash)
            .map { return $0[0] }
    }
    
    /// Checks the load status for each script by their provided SHA1 hashes.
    ///
    /// See [https://redis.io/commands/script-exists](https://redis.io/commands/script-exists)
    /// - Parameter hashes: The list of script SHA1 hashes to look for in the Redis instance.
    /// - Returns: A collection matching the same order as the `hashes` provided, with the values of `true` if the script has been loaded or `false` if it has not.
    public func scriptExists(_ hashes: String...) -> EventLoopFuture<[Bool]> {
        return self.scriptExists(hashes)
    }
    
    /// Checks the load status for each script by their provided SHA1 hashes.
    ///
    /// See [https://redis.io/commands/script-exists](https://redis.io/commands/script-exists)
    /// - Parameter hashes: The list of script SHA1 hashes to look for in the Redis instance.
    /// - Returns: A collection matching the same order as the `hashes` provided, with the values of `true` if the script has been loaded or `false` if it has not.
    public func scriptExists(_ hashes: [String]) -> EventLoopFuture<[Bool]> {
        var args: [RESPValue] = [
            .init(bulk: "EXISTS")
        ]
        args.append(convertingContentsOf: hashes)
        
        return send(command: "SCRIPT", with: args)
            .convertFromRESPValue(to: [Int].self)
            .map { values in return values.map({ $0 == 1 }) }
    }
}

// MARK: General

extension RedisClient {
    /// Flush the Redis Lua script cache.
    ///
    /// This command is primarily useful for development and testing.
    /// Lua scripts take up a relatively small amount of memory in Redis, and the documentation states you should not need to routinely flush scripts in your application.
    ///
    /// See [https://redis.io/commands/script-flush](https://redis.io/commands/script-flush)
    /// - Returns: An `EventLoopFuture` that resolves when the operation has completed.
    @inlinable
    public func flushScripts() -> EventLoopFuture<Void> {
        let args: [RESPValue] = [
            .init(bulk: "FLUSH"),
        ]
        return send(command: "SCRIPT", with: args)
            .map { _ in () }
    }
}
