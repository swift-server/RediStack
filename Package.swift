// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "nio-redis",
    products: [
        .library(name: "NIORedis", targets: ["NIORedis"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", .branch("master")),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0")
    ],
    targets: [
        .target(name: "NIORedis", dependencies: ["NIO", "Logging"]),
        .testTarget(name: "NIORedisTests", dependencies: ["NIORedis", "NIO"])
    ]
)
