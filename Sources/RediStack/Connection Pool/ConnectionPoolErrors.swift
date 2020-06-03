//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2020 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import protocol Foundation.LocalizedError

/// If something goes wrong with any part of the Redis connection pool, errors of this type will be thrown.
public struct RedisConnectionPoolError: LocalizedError, Equatable {
    private var baseError: BaseError

    init(baseError: BaseError) {
        self.baseError = baseError
    }

    internal enum BaseError: Equatable {
        case poolClosed
        case timedOutWaitingForConnection
        case noAvailableConnectionTargets
    }

    /// The connection pool has already been closed, but the user has attempted to perform another operation on it.
    public static let poolClosed = RedisConnectionPoolError(baseError: .poolClosed)

    /// The timeout for waiting for a connection expired before we got a connection.
    public static let timedOutWaitingForConnection = RedisConnectionPoolError(baseError: .timedOutWaitingForConnection)

    /// The pool has been configured without available connection targets, so there is nowhere to connect to.
    public static let noAvailableConnectionTargets = RedisConnectionPoolError(baseError: .noAvailableConnectionTargets)
}
