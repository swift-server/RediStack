// swift-tools-version:5.0
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

import PackageDescription

let package = Package(
    name: "swift-redis-nio-client",
    products: [
        .library(name: "RedisNIO", targets: ["RedisNIO"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-metrics.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0")
    ],
    targets: [
        .target(name: "RedisNIO", dependencies: ["NIO", "Logging", "Metrics"]),
        .target(name: "RedisNIOTestUtils", dependencies: ["NIO", "RedisNIO"]),
        .testTarget(name: "RedisNIOTests", dependencies: ["RedisNIO", "NIO", "RedisNIOTestUtils"])
    ]
)
