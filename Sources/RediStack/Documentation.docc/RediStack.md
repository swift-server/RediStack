# ``RediStack``

A non-blocking Swift client for Redis built on top of SwiftNIO.

## Overview

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

> Important: Use of `wait()` was used here for simplicity. Never call this method on an `eventLoop`!

## Topics

### Creating Connections

- ``RedisConnection``
- ``RedisConnectionPool``

### Sending Commands

- ``RedisClient``
- ``RedisCommand``
- ``RedisKey``

### Pub/Sub

- ``RedisChannelName``

### Error Handling

- ``RedisError``
- ``RedisClientError``
- ``RedisConnectionPoolError``

### Monitoring

- ``RedisMetrics``
- ``RedisLogging``

### Creating Redis NIO Pipelines

- ``RedisByteDecoder``
- ``RedisCommandHandler``
- ``RedisMessageEncoder``
- ``RedisPubSubHandler``

### Redis Serialization Protocol

- ``RESPTranslator``
- ``RESPValue``
- ``RESPValueConvertible``
