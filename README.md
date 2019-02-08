[![License](https://img.shields.io/badge/License-Apache%202.0-yellow.svg)](https://www.apache.org/licenses/LICENSE-2.0.html)
[![Build](https://img.shields.io/circleci/project/github/Mordil/nio-redis/master.svg?logo=circleci)](https://circleci.com/gh/Mordil/nio-redis/tree/master)
[![Swift](https://img.shields.io/badge/Swift-5.0-brightgreen.svg?colorA=orange&colorB=4E4E4E)](https://swift.org)
[![Redis](https://img.shields.io/badge/Redis-5-brightgreen.svg?colorA=red&colorB=4E4E4E)](https://redis.io/download)

# NIORedis

A non-blocking Swift driver for Redis built with [SwiftNIO](https://github.com/apple/swift-nio).

This package defines everything you need to work with Redis through the [**Re**dis **S**eralization **P**rotocol (RESP)](https://redis.io/topics/protocol).

* Pitch discussion: [Swift Server Forums](https://forums.swift.org/t/swiftnio-redis-client/19325)
* Proposal: [SSWG-0004](https://github.com/swift-server/sswg/blob/56a26b50ade45d624b54abe13c7d1f88526f9bb1/proposals/0004-nio-redis.md)

## Installation

To install `NIORedis`, just add the package as a dependency in your [**Package.swift**](https://github.com/apple/swift-package-manager/blob/master/Documentation/PackageDescriptionV4.md#dependencies)

```swift
dependencies: [
    .package(url: "https://github.com/Mordil/nio-redis.git", .upToNextMinor(from: "0.2.0")
]
```

and run the following command: `swift package resolve`

## Getting Started

`NIORedis` is ready to use right after installation.

```swift
import NIORedis

let driver = NIORedisDriver(ownershipModel: .internal(threadCount: 2))

let connection = try driver.makeConnection().wait()

let result = try connection.set("my_key", to: "some value")
    .flatMap { return connection.get("my_key" }
    .wait()

print(result) // Optional("some value")
```

## Contributing

Check out [CONTRIBUTING.md](CONTRIBUTING.md) for more information on how to help with NIORedis.

It is highly recommended to use [Docker](https://docker.com) to install Redis locally.

```bash
docker run -d -p 6379:6379 --name nioredis redis:5
```

Otherwise, install Redis directly on your machine from [Redis.io](https://redis.io/download).
