# NIORedis: Client for Redis server built on NIO
This package includes two modules: `NIORedis` and `Redis`, which provide clients that handle connection to, authorizing, and 
executing commands against a Redis server.

`NIORedis` provides channel handlers for encoding / decoding between Swift native types and [Redis' Serialization Protocol (RESP)](https://redis.io/topics/protocol).

`Redis` is an abstraction layer that wraps `NIORedis` to be callback based with `DispatchQueue`.

# Motivation
Implementations of Redis connections have decayed as newer capabilities of the Swift STD Library, SwiftNIO, and the Swift language itself have developed.

As part of the iniative of trying to push the ecosystem to be centered around SwiftNIO, a framework-agnostic driver on Redis can provide an
easier time for feature development on Redis.

# Proposed Solution
A barebones implementation is available at [mordil/nio-redis](https://github.com/mordil/nio-redis).

The following are already implemented, with unit tests:

- [Connection and Authorization](https://github.com/Mordil/nio-redis/blob/master/Sources/NIORedis/NIORedis.swift#L35)
- [Raw commands](https://github.com/Mordil/nio-redis/blob/master/Sources/NIORedis/NIORedisConnection.swift#L33)
- [Convienence methods for:](https://github.com/Mordil/nio-redis/blob/master/Sources/NIORedis/Commands/BasicCommands.swift#L4)
  - GET
  - SET
  - AUTH
  - DEL
  - SELECT
  - EXPIRE
- NIO-wrapped abstractions for
  - [Client](https://github.com/Mordil/nio-redis/blob/master/Sources/Redis/Redis.swift)
  - [Connection](https://github.com/Mordil/nio-redis/blob/master/Sources/Redis/RedisConnection.swift)
  - [Pipelines](https://github.com/Mordil/nio-redis/blob/master/Sources/Redis/RedisPipeline.swift)
  - GET command
- Unit tests for
  - Response decoding to native Swift
  - Message encoding to RESP
  - Connections
  - implemented commands
  - pipelines

This package is a re-implementation of [vapor/redis](https://github.com/vapor/redis) stripped down to only build on SwiftNIO to be framework agnostic.

Much of this was inspired by the [NIOPostgres pitch](https://forums.swift.org/t/pitch-swiftnio-based-postgresql-client/18020).

# Details Solution

> **NOTE: This this is written against SwiftNIO 2.0, and as such requires Swift 5.0!**

This is to take advantage of the [`Result`](https://github.com/apple/swift-evolution/blob/master/proposals/0235-add-result.md) type in the `Redis` module,
and to stay ahead of development of the next version of SwiftNIO.

## NIORedis
Most use of this library will be focused on a `NIORedisConnection` type that works explicitly in a SwiftNIO `EventLoop` context - with
return values all being `EventLoopFuture`.

```swift
import NIORedis

let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
let redis = NIORedis(executionModel: .eventLoopGroup(elg))

// connections

// passing a value to `password` will automatically authenticate with Redis before resolving the connection
let connection = try redis.makeConnection(
    hostname: "localhost", // this is the default
    port: 6379, // this is the default
    password: "MY_PASS" // default is `nil`
).wait()
print(connection) // NIORedisConnection

// convienence methods for commands

let result = try connection.set("my_key", to: "some value")
    .then {
        return connection.get("my_key")
    }.wait()
print(result) // Optional("some value")

// raw commands

let keyCount = try connection.command("DEL", [RESPValue(bulk: "my_key")])
    .thenThrowing { res in
        guard case let .integer(count) else {
            // throw Error
        }
        return count
    }.wait()
print(keyCount) // 1

// cleanup 

connection.close()
try redis.terminate()
try elg.syncShutdownGracefully()
```

### RESPValue & RESPValueConvertible
This is a 1:1 mapping enum of the `RESP` types: `Simple String`, `Bulk String`, `Array`, `Integer` and `Error`.

Conforming to `RESPValueConvertible` allows Swift types to more easily convert between `RESPValue` and native types.

`Array`, `Data`, `Float`, `Double`, `FixedWidthInteger`, `String`, and of course `RESPValue` all conform in this package.

A `ByteToMessageDecoder` and `MessageToByteEncoder` are used for the conversion process on connections.

### NIORedisConnection
This class uses a `ChannelInboundHandler` that handles the actual process of sending and receiving commands.

While it does handle a queue of messages, so as to not be blocking, pipelining is implemented with `NIORedisPipeline`.

### NIORedisPipeline
A `NIORedisPipeline` is a quick abstraction that buffers an array of complete messages as `RESPValue`, and executing them in sequence after a
user has invoked `execute()`.

It returns an `EventLoopFuture<[RESPValue]>` with the results of all commands executed - unless one errors.

## Redis

To support contexts where someone either doesn't want to work in a SwiftNIO context, the `Redis` module provides a callback-based interface
that wraps all of `NIORedis`.

A `Redis` instance manages a `NIORedis` object under the hood, with `RedisConnection` doing the same for `NIORedisConnection`.

```swift
import Redis

let redis = Redis(threadCount: 1) // default is 1

// connections

// passing a value to `password` will automatically authenticate with Redis before resolving the connection
redis.makeConnection(
    hostname: "localhost", // this is the default
    port: 6379, // this is the default
    password: "MY_PASS", // default is `nil`
    queue: DispatchQueue(label: "com.MyPackage.redis") // default is `.main`
) { result in
    switch result {
    case .success(let conn):
        showCommands(on: conn)
    case .failure(let error):
        fatalError("Could not create RedisConnection!")
    }
}

// convienence methods for commands

func showCommands(on conn: RedisConnection) {
    conn.get("my_key") { result in
        switch result {
        case .success(let value):
            // use value, which is String?
        case .failure(let error):
            // do something on error
        }
    }
}

// cleanup is handled by deinit blocks
```
