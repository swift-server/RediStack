# RediStack

[![SSWG Sandbox Incubating Badge](https://img.shields.io/badge/sswg-sandbox-lightgrey.svg)][SSWG Incubation]
[![Documentation](http://img.shields.io/badge/read_the-docs-2196f3.svg)][Documentation]
[![MIT License](http://img.shields.io/badge/license-Apache-brightgreen.svg)][Apache License]
[![Swift 5.6](http://img.shields.io/badge/swift-5.6-brightgreen.svg)][Swift 5.6]

**RediStack** (pronounced like "ready stack") is a _non-blocking_ Swift client for [Redis](https://redis.io) built on top of [SwiftNIO](https://github.com/apple/swift-nio).

<table><thead><tr align="center"><th width="9999">
The <a href="https://gitlab.com/swift-server-community/RediStack" rel="nofollow noreferrer noopener" target="_blank">GitLab repository</a> is a <b>read-only</b> mirror of the GitHub repository. For issues and pull requests, <a href="https://github.com/swift-server/RediStack" rel="nofollow noreferrer noopener" target="_blank">please visit GitHub</a>.
</th></tr></thead></table>

## Introduction

It communicates over the network using Redis' [**Re**dis **S**eralization **P**rotocol (RESP2)](https://redis.io/topics/protocol).

This library is primarily developed for Redis v5, but is backwards compatible to Redis v3.

## Installing

To install **RediStack**, just add the package as a dependency in your **Package.swift**.
foo
```swift
dependencies: [
    .package(url: "https://github.com/swift-server/RediStack.git", from: "1.4.1")
]
```

## Getting Started

**RediStack** is quick to use - all you need is an [`EventLoop`](https://swiftpackageindex.com/apple/swift-nio/main/documentation/niocore/eventloop) from **SwiftNIO**.

```swift
import NIOCore
import NIOPosix
import RediStack

let eventLoop: EventLoop = NIOSingletons.posixEventLoopGroup.any()
let connection = RedisConnection.make(
    configuration: try .init(hostname: "127.0.0.1"),
    boundEventLoop: eventLoop
).wait()

let result = try connection.set("my_key", to: "some value")
    .flatMap { return connection.get("my_key") }
    .wait()

print(result) // Optional("some value")
```

> _**Note**: Use of `wait()` was used here for simplicity. Never call this method on an `eventLoop`!_

## Documentation

The docs for the latest tagged release are always available at the [Swift Package Index][Documentation].

## Questions

For bugs or feature requests, file a new [issue](https://github.com/swift-server/RediStack/issues/new).

## Changelog

[SemVer](https://semver.org/) changes are documented for each release on the [releases page][Releases].

## Contributing

Check out [CONTRIBUTING.md](https://github.com/swift-server/RediStack/blob/main/CONTRIBUTING.md) for more information on how to help with **RediStack**.

## Contributors

Check out [CONTRIBUTORS.txt](https://github.com/swift-server/RediStack/blob/main/CONTRIBUTORS.txt) to see the full list. This list is updated for each release.

## Swift on Server Ecosystem

**RediStack** is part of the [Swift on Server Working Group][SSWG] ecosystem - currently recommended as [**Sandbox Maturity**][SSWG Incubation].

| Proposal | Pitch | Discussion | Review | Vote |
|:---:|:---:|:---:|:---:|:---:|
| [SSWG-0004](https://github.com/swift-server/sswg/blob/main/proposals/0004-nio-redis.md) | [2019-01-07](https://forums.swift.org/t/swiftnio-redis-client/19325) | [2019-04-01](https://forums.swift.org/t/discussion-nioredis-nio-based-redis-driver/22455) | [2019-06-09](https://forums.swift.org/t/feedback-redisnio-a-nio-based-redis-driver/25521) | [2019-06-27](https://forums.swift.org/t/june-27th-2019/26580) |

## Language and Platform Support

Any given release of **RediStack** will support at least the latest version of Swift on a given platform plus **2** previous versions, at the time of the release.

Major version releases will be scheduled around official Swift releases, taking no longer **3 months** from the Swift release.

Major version releases will drop support for any version of Swift older than the last **3** Swift versions.

This policy is to balance the desire for as much backwards compatibility as possible, while also being able to take advantage of new Swift features for the best API design possible.

## License

[Apache 2.0][Apache License]

Copyright (c) 2019-present, Nathan Harris (@mordil)

_This project contains code written by others not affliated with this project. All copyright claims are reserved by them. For a full list, with their claimed rights, see [NOTICE.txt](https://github.com/swift-server/RediStack/blob/main/NOTICE.txt)_

_**Redis** is a registered trademark of **Redis Labs**. Any use of their trademark is under the established [trademark guidelines](https://redis.io/topics/trademark) and does not imply any affiliation with or endorsement by them, and all rights are reserved by them._

_**Swift** is a registered trademark of **Apple, Inc**. Any use of their trademark does not imply any affiliation with or endorsement by them, and all rights are reserved by them._

[SSWG Incubation]: https://www.swift.org/sswg/incubation-process.html
[SSWG]: https://www.swift.org/sswg/
[Documentation]: https://swiftpackageindex.com/swift-server/RediStack/documentation
[Apache License]: LICENSE.txt
[Swift 5.6]: https://swift.org
[Releases]: https://github.com/swift-server/RediStack/releases
