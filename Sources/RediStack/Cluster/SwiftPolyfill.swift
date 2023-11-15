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

/// We use this protocol internally to abstract over TaskGroups. On Linux we can always use a `DiscardingTaskGroup`,
/// but to support Swift 5.8 on macOS we need to fallback to the original TaskGroup.
@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
protocol DiscardingTaskGroupProtocol {
    mutating func addTask(priority: TaskPriority?, operation: @escaping @Sendable () async -> Void)
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension DiscardingTaskGroupProtocol {
    mutating func addTask(_ operation: @escaping @Sendable () async -> Void) {
        self.addTask(priority: nil, operation: operation)
    }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension TaskGroup: DiscardingTaskGroupProtocol where ChildTaskResult == Void {}

#if swift(>=5.9) || (swift(>=5.8) && os(Linux))
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension DiscardingTaskGroup: DiscardingTaskGroupProtocol {}
#endif

#if swift(<5.9)
// This should be removed once we support Swift 5.9+ only
extension AsyncStream {
    static func makeStream(
        of elementType: Element.Type = Element.self,
        bufferingPolicy limit: Continuation.BufferingPolicy = .unbounded
    ) -> (stream: AsyncStream<Element>, continuation: AsyncStream<Element>.Continuation) {
        var continuation: AsyncStream<Element>.Continuation!
        let stream = AsyncStream<Element>(bufferingPolicy: limit) { continuation = $0 }
        return (stream: stream, continuation: continuation!)
    }
}
#endif
