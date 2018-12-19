// swift-tools-version:4.2

import PackageDescription

let package = Package(
    name: "Redis",
    products: [
        .library(name: "NIORedis", targets: ["NIORedis"]),
        //.library(name: "Redis", targets: [""])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", .branch("master"))
    ],
    targets: [
        .target(name: "NIORedis", dependencies: ["NIO"]),
        //.target(name: "Redis", dependencies: ["NIORedis"]),
        .testTarget(name: "NIORedisTests", dependencies: ["NIORedis", "NIO"]),
        //.testTarget(name: "RedisTests", dependencies: ["Redis"])
    ]
)
