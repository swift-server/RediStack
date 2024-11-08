//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2020 Apple Inc. and the RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOCore

extension RedisKey.Lifetime {
    /// The lifetime duration for a `RedisKey` which has an expiry set.
    public enum Duration: Comparable, Hashable {
        /// The remaining time-to-live in seconds.
        case seconds(Int64)
        /// The remaining time-to-live in milliseconds.
        case milliseconds(Int64)

        /// The remaining time-to-live.
        public var timeAmount: TimeAmount {
            switch self {
            case .seconds(let amount): return .seconds(amount)
            case .milliseconds(let amount): return .milliseconds(amount)
            }
        }

        public static func < (lhs: Duration, rhs: Duration) -> Bool {
            lhs.timeAmount < rhs.timeAmount
        }

        public static func == (lhs: Duration, rhs: Duration) -> Bool {
            lhs.timeAmount == rhs.timeAmount
        }
    }
}

extension RedisKey {
    /// The lifetime of a `RedisKey` as determined by `ttl` or `pttl`.
    public enum Lifetime: Hashable {
        /// The key does not exist.
        case keyDoesNotExist
        /// The key exists but has no expiry associated with it.
        case unlimited
        /// The key exists for the given lifetime.
        case limited(Duration)

        /// The remaining time-to-live for the key, or `nil` if the key does not exist or will not expire.
        public var timeAmount: TimeAmount? {
            switch self {
            case .keyDoesNotExist, .unlimited: return nil
            case .limited(let lifetime): return lifetime.timeAmount
            }
        }

        internal init(seconds: Int64) {
            switch seconds {
            case -2:
                self = .keyDoesNotExist
            case -1:
                self = .unlimited
            default:
                self = .limited(.seconds(seconds))
            }
        }

        internal init(milliseconds: Int64) {
            switch milliseconds {
            case -2:
                self = .keyDoesNotExist
            case -1:
                self = .unlimited
            default:
                self = .limited(.milliseconds(milliseconds))
            }
        }
    }
}
