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

import Metrics
import NIOConcurrencyHelpers

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
    /// namespaced description in the form of `"RediStack.<rawValue>"`.
    public enum Label: String, CustomStringConvertible {
        case totalConnectionCount
        case activeConnectionCount
        case commandSuccessCount
        case commandFailureCount
        case commandRoundTripTime

        public var description: String {
            return "RediStack.\(self.rawValue)"
        }
    }

    /// The wrapped `Metrics.Gauge` maintaining the current number of connections this library has active.
    public static var activeConnectionCount = ActiveConnectionGauge()
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

/// A specialized wrapper class for working with `Metrics.Gauge` objects for the purpose of an incrementing or decrementing count of active Redis connections.
public class ActiveConnectionGauge {
    private let gauge = Gauge(label: .activeConnectionCount)
    private let count:  NIOAtomic<Int> = .makeAtomic(value: 0)
    
    /// The number of the connections that are currently reported as active.
    var currentCount: Int { return count.load() }
    
    internal init() { }
    
    /// Increments the current count by the amount specified.
    /// - Parameter amount: The number to increase the current count by. Default is `1`.
    public func increment(by amount: Int = 1) {
        _ = self.count.add(amount)
        self.gauge.record(self.count.load())
    }
    
    /// Decrements the current count by the amount specified.
    /// - Parameter amount: The number to decrease the current count by. Default is `1`.
    public func decrement(by amount: Int = 1) {
        _ = self.count.sub(amount)
        self.gauge.record(self.count.load())
    }
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
