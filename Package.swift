// swift-tools-version:4.2

import PackageDescription

let package = Package(
    name: "nio-redis",
    products: [
        .library(name: "NIORedis", targets: ["NIORedis"]),
        //.library(name: "Redis", targets: [""])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "1.0.0")
    ],
    targets: [
        .target(name: "NIORedis", dependencies: ["NIO"]),
        //.target(name: "Redis", dependencies: ["NIORedis"]),
        .testTarget(name: "NIORedisTests", dependencies: ["NIORedis", "NIO"]),
        //.testTarget(name: "RedisTests", dependencies: ["Redis"])
    ]
)
