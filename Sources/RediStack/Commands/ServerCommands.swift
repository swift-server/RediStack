//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2020-2022 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIO

// MARK: Server

extension RedisCommand {
    /// [SWAPDB](https://redis.io/commands/swapdb)
    /// - Parameters:
    ///     - first: The index of the first database.
    ///     - second: The index of the second database.
    public static func swapdb(_ first: Int, with second: Int) -> RedisCommand<Bool> {
        let args: [RESPValue] = [
            .init(bulk: first),
            .init(bulk: second)
        ]
        return .init(keyword: "SWAPDB", arguments: args) {
            return (try $0.map()) == "OK"
        }
    }
}

// MARK: -

extension RedisClient {
    /// Swaps the data of two Redis databases by their index IDs.
    ///
    /// See ``RedisCommand/swapdb(_:with:)``
    /// - Parameters:
    ///     - first: The index of the first database.
    ///     - second: The index of the second database.
    /// - Returns: A `NIO.EventLoopFuture` that resolves `true` if the command succeed or `false` if it didn't.
    public func swapDatabase(_ first: Int, with second: Int) -> EventLoopFuture<Bool> {
        return self.send(.swapdb(first, with: second))
    }
}
