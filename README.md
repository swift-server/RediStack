<div align="center">
<p><img src="https://repository-images.githubusercontent.com/161592209/e0dfc700-a1c2-11e9-9302-a4b00958c76f" width="350" alt="RediStack logo"></p>

<p>
    [![SSWG Sandbox Incubating Badge](https://img.shields.io/badge/sswg-sandbox-lightgrey.svg)][SSWG Incubation]
    [![Documentation](http://img.shields.io/badge/read_the-docs-2196f3.svg)][Documentation]
    [![MIT License](http://img.shields.io/badge/license-MIT-brightgreen.svg)][Apache License]
    [![Swift 5.6](http://img.shields.io/badge/swift-5.6-brightgreen.svg)][Swift 5.6]
</p>
</div>

<table><thead><tr align="center"><th width="9999">
The <a href="https://gitlab.com/swift-server-community/RediStack" rel="nofollow noreferrer noopener" target="_blank">GitLab repository</a> is a <b>read-only</b> mirror of the GitHab repository. For issues and pull requests, <a href="https://github.com/swift-server/RediStack" rel="nofollow noreferrer noopener" target="_blank">please visit GitHub</a>.
</th></tr></thead></table>

## Introduction

**RediStack** (pronounced like "ready stack") is a _non-blocking_ Swift client for [Redis](https://redis.io) built on top of [SwiftNIO](https://github.com/apple/swift-nio).

It communicates over the network using Redis' [**Re**dis **S**eralization **P**rotocol (RESP2)](https://redis.io/topics/protocol).

This library is primarily developed for Redis v5, but is backwards compatible to Redis v3**¹**.

The table below lists the major releases alongside their compatible language, dependency, and Redis versions.

| RediStack Release | [Swift](https://swift.org/download) | [Redis](https://redis.io) | [SwiftNIO](https://github.com/apple/swift-nio) | [SwiftLog](https://github.com/apple/swift-log) | [SwiftMetrics](https://github.com/apple/swift-metrics) |
|:-----------------:|:-----------------------------------:|:-------------------------:|:----------------------------------------------:|:----------------------------------------------:|:------------------------------:|
| `from: "1.0.0"` | 5.1+ | 3.x**¹** < 6.x | 2.x | 1.x | 1.x ..< 3.0 |
| `from: "1.4.0"` | 5.5+ | 3.x**¹** < 6.x | 2.x | 1.x | 1.x ..< 3.0 |

> **¹** _Use of newer Redis features on older Redis versions is done at your own risk. See Redis' release notes for [v5](https://raw.githubusercontent.com/antirez/redis/5.0/00-RELEASENOTES), [v4](https://raw.githubusercontent.com/antirez/redis/4.0/00-RELEASENOTES), and [v3](https://raw.githubusercontent.com/antirez/redis/3.0/00-RELEASENOTES) for what is supported for each version of Redis._

### Supported Operating Systems

**RediStack** runs anywhere that is officially supported by the [Swift project](https://swift.org/download/#releases)**²**.

> **²** See the [platform support matrix below for more details](#language-and-platform-support).

## Installing

To install **RediStack**, just add the package as a dependency in your **Package.swift**.

```swift
dependencies: [
    .package(url: "https://github.com/swift-server/RediStack.git", from: "1.4.1")
]
```

## Getting Started

**RediStack** is quick to use - all you need is an [`EventLoop`](https://apple.github.io/swift-nio/docs/current/NIO/Protocols/EventLoop.html) from **SwiftNIO**.

```swift
import NIO
import RediStack

let eventLoop: EventLoop = ...
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
| [SSWG-0004](https://github.com/swift-server/sswg/blob/master/proposals/0004-nio-redis.md) | [2019-01-07](https://forums.swift.org/t/swiftnio-redis-client/19325) | [2019-04-01](https://forums.swift.org/t/discussion-nioredis-nio-based-redis-driver/22455) | [2019-06-09](https://forums.swift.org/t/feedback-redisnio-a-nio-based-redis-driver/25521) | [2019-06-27](https://forums.swift.org/t/june-27th-2019/26580) |

## Language and Platform Support

Any given release of **RediStack** will support at least the latest version of Swift on a given platform plus **2** previous versions, at the time of the release.

Major version releases will be scheduled around official Swift releases, taking no longer **3 months** from the Swift release.

Major version releases will drop support for any version of Swift older than the last **3** Swift versions.

This policy is to balance the desire for as much backwards compatibility as possible, while also being able to take advantage of new Swift features for the best API design possible.

The following table shows the combination of Swift language versions and operating systems that
receive regular unit testing (either in development, or with CI).

| Platform                    | Swift 5.5 | 5.6 | 5.7 | Trunk |
|:----------------------------|:---------:|:---:|:---:|:-----:|
| macOS Latest (M1)           |   |   | ✅ |   |
| Ubuntu 20.04 (Focal)        | ✅ | ✅ | ✅ | ✅ |
| Ubuntu 18.04 (Bionic)       | ✅ | ✅ | ✅ | ✅ |
| Ubuntu 16.04 (Xenial)**³**  | ✅ | ❌ | ❌ | ❌ |
| Amazon Linux 2              | ✅ | ✅ | ✅ | ✅ |
| CentOS 8**³**               | ✅ | ❌ | ❌ | ❌ |
| CentOS 7                    | ✅ | ✅ | ✅ | ✅ |

> **³** _CentOS 8 and Ubuntu 16.04 are no longer officially supported by Swift after [Swift 5.5](https://github.com/apple/swift-docker/pull/273)._


## License

[Apache 2.0][Apache License]

Copyright (c) 2019-present, Nathan Harris (@mordil)

_This project contains code written by others not affliated with this project. All copyright claims are reserved by them. For a full list, with their claimed rights, see [NOTICE.txt](https://github.com/swift-server/RediStack/blob/main/NOTICE.txt)_

_**Redis** is a registered trademark of **Redis Labs**. Any use of their trademark is under the established [trademark guidelines](https://redis.io/topics/trademark) and does not imply any affiliation with or endorsement by them, and all rights are reserved by them._

_**Swift** is a registered trademark of **Apple, Inc**. Any use of their trademark does not imply any affiliation with or endorsement by them, and all rights are reserved by them._

[SSWG Incubation]: https://www.swift.org/sswg/incubation-process.html
[SSWG]: https://www.swift.org/sswg/
[Documentation]: https://swiftpackageindex.com/swift-server/RediStack/documentation
[Apache License]: LICENSE
[Swift 5.6]: https://swift.org
[Releases]: https://github.com/swift-server/RediStack/releases
