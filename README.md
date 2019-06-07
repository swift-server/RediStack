| The [GitHub repository](https://github.com/Mordil/swift-redis-nio-client) is a **read-only** mirror of the GitLab repository. For issues and merge requests, [please visit GitLab](https://gitlab.com/mordil/swift-redis-nio-client). |
|---|

[![License](https://img.shields.io/badge/License-Apache%202.0-yellow.svg)](./LICENSE.txt)
[![Build](https://gitlab.com/Mordil/swift-redis-nio-client/badges/master/pipeline.svg)](https://gitlab.com/Mordil/swift-redis-nio-client/pipelines)
[![Swift](https://img.shields.io/badge/Swift-5.0-brightgreen.svg?colorA=orange&colorB=4E4E4E)](https://swift.org)
[![Redis](https://img.shields.io/badge/Redis-5-brightgreen.svg?colorA=red&colorB=4E4E4E)](https://redis.io/download)

# Swift Redis NIO Client

A non-blocking Swift client for [Redis](https://redis.io/) built on top of [SwiftNIO](https://github.com/apple/swift-nio).

This package defines everything you need to work with Redis through the [**Re**dis **S**eralization **P**rotocol (RESP)](https://redis.io/topics/protocol).

**RedisNIO** is part of the [Swift on Server Working Group](https://github.com/swift-server/sswg) ecosystem.

| Proposal | Pitch | Discussion | Review | Vote |
|----------|-------|------------|--------|------|
| [SSWG-0004](https://github.com/swift-server/sswg/blob/master/proposals/0004-nio-redis.md) | [2019-01-07](https://forums.swift.org/t/swiftnio-redis-client/19325) | [2019-04-01](https://forums.swift.org/t/discussion-nioredis-nio-based-redis-driver/22455) | **TBD** | **TBD** |

## :package: Installation

To install **RedisNIO**, just add the package as a dependency in your [**Package.swift**](https://github.com/apple/swift-package-manager/blob/master/Documentation/PackageDescriptionV4.md#dependencies)

```swift
dependencies: [
    .package(url: "https://github.com/Mordil/swift-redis-nio-client.git", from: "1.0.0-alpha.1")
]
```

and run the following command: `swift package resolve`

## :zap: Getting Started

**RedisNIO** is ready to use right after installation.

```swift
import RedisNIO

let connection = Redis.makeConnection(
    to: try .init(ipAddress: "127.0.0.1", port: 6379),
    password: "my_pass"
).wait()

let result = try connection.set("my_key", to: "some value")
    .flatMap { return connection.get("my_key" }
    .wait()

print(result) // Optional("some value")
```

## :closed_book: Documentation

API Documentation is generated every time a new release is published.

The latest version's docs are always available at https://mordil.gitlab.io/swift-redis-nio-client

## :construction: Contributing

Check out [CONTRIBUTING.md](CONTRIBUTING.md) for more information on how to help with **RedisNIO**.

It is highly recommended to use [Docker](https://docker.com) to install Redis locally.

```bash
docker run -d -p 6379:6379 --name redis redis:5
```

Otherwise, install Redis directly on your machine from [Redis.io](https://redis.io/download).
