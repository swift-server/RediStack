//===----------------------------------------------------------------------===//
//
// This source file is part of the RedisNIO open source project
//
// Copyright (c) 2019 RedisNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RedisNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIO

extension EventLoopFuture where Value == RESPValue {
    /// Attempts to convert the `RESPValue` to the desired `RESPValueConvertible` type.
    /// If the `RESPValueConvertible.init(_:)` returns `nil`, then the `EventLoopFuture` will fail.
    /// - Parameter to: The desired type to convert to.
    /// - Returns: An `EventLoopFuture` that resolves a value of the desired type.
    @inlinable
    public func convertFromRESPValue<T>(
        to type: T.Type = T.self,
        file: StaticString = #function,
        function: StaticString = #function,
        line: UInt = #line
    )
        -> EventLoopFuture<T> where T: RESPValueConvertible
    {
        return self.flatMapThrowing {
            guard let value = T(fromRESP: $0) else {
                throw RedisNIOError.responseConversion(to: type)
            }
            return value
        }
    }
}
