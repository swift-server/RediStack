// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "nio-redis",
    products: [
        .library(name: "NIORedis", targets: ["NIORedis"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", .branch("master"))
    ],
    targets: [
        .target(name: "NIORedis", dependencies: ["NIO"]),
        .testTarget(name: "NIORedisTests", dependencies: ["NIORedis", "NIO"])
    ]
)
