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

import Metrics

/// The system funnel for all `Metrics` interactions from the Redis library.
///
/// It is highly recommended to not interact with this directly, and to let the library
/// use it how it sees fit.
///
/// There is a nested enum type of `RedisMetrics.Label` that is available to query, match, etc. the
/// labels used for all of the `Metrics` types created by the Redis library.
public struct RedisMetrics {
    /// An enumeration of all the labels used by the Redis library for various `Metrics` data points.
    ///
    /// Each is backed by a raw string, and this type is `CustomStringConvertible` to receive a
    /// namespaced description in the form of `"RedisNIO.<rawValue>"`.
    public enum Label: String, CustomStringConvertible {
        case totalConnectionCount
        case activeConnectionCount
        case commandSuccessCount
        case commandFailureCount
        case commandRoundTripTime

        public var description: String {
            return "RedisNIO.\(self.rawValue)"
        }
    }

    private static let activeConnectionCountGauge = Gauge(label: .activeConnectionCount)
    /// The current number of connections this library has active.
    /// - Note: Changing this number will update the `Metrics.Gauge` stored for recording the new value.
    public static var activeConnectionCount: Int = 0 {
        didSet {
            activeConnectionCountGauge.record(activeConnectionCount)
        }
    }
    /// The `Metrics.Counter` that retains the number of connections made since application startup.
    public static let totalConnectionCount = Counter(label: .totalConnectionCount)
    /// The `Metrics.Counter` that retains the number of commands that successfully returned from Redis
    /// since application startup.
    public static let commandSuccessCount = Counter(label: .commandSuccessCount)
    /// The `Metrics.Counter` that retains the number of commands that failed from errors returned
    /// by Redis since application startup.
    public static let commandFailureCount = Counter(label: .commandFailureCount)
    /// The `Metrics.Timer` that receives command response times in nanoseconds from when a command
    /// is first sent through the `NIO.Channel`, to when the response is first resolved.
    public static let commandRoundTripTime = Timer(label: .commandRoundTripTime)

    private init() { }
}

extension Metrics.Counter {
    @inline(__always)
    convenience init(label: RedisMetrics.Label) {
        self.init(label: label.description)
    }
}

extension Metrics.Gauge {
    @inline(__always)
    convenience init(label: RedisMetrics.Label) {
        self.init(label: label.description)
    }
}

extension Metrics.Timer {
    @inline(__always)
    convenience init(label: RedisMetrics.Label) {
        self.init(label: label.description)
    }
}
