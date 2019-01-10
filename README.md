# NIORedis: A Redis Driver built on SwiftNIO

* Pitch discussion: [Swift Server Forums](https://forums.swift.org/t/swiftnio-redis-client/19325/13)

> **NOTE: This this is written against SwiftNIO 2.0, and as such requires Swift 5.0!**

This is to take advantage of the [`Result`](https://github.com/apple/swift-evolution/blob/master/proposals/0235-add-result.md) type in the `DispatchRedis` module,
and to stay ahead of development of the next version of SwiftNIO.

```swift
import NIORedis

let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
let driver = RedisDriver(ownershipModel: .external(elg))

// connections

// passing a value to 'password' will automatically authenticate with Redis before resolving the connection
let connection = try redis.makeConnection(
    hostname: "localhost", // this is the default
    port: 6379, // this is the default
    password: "MY_PASS" // default is 'nil'
).wait()

// convenience methods for commands

let result = try conneciton.set("my_key", to: "some value")
    .then { return connection.get("my_key")}
    .wait()
print(result) // Optional("some value")

// raw commands

let keyCount = try connection.command("DEL", [RESPValue(bulk: "my_key")])
    .thenThrowing { response in
        guard case let .integer(count) else {
            // throw error
        }
        return count
    }
    .wait()
print(keyCount) // 1

// cleanup

connection.close()
    .thenThrowing { try redis.terminate() }
    .whenSuccess { try elg.syncShutdownGracefully() }
```

### RESPValue & RESPValueConvertible
This is a 1:1 mapping enum of the `RESP` types: `Simple String`, `Bulk String`, `Array`, `Integer` and `Error`.

Conforming to `RESPValueConvertible` allows Swift types to more easily convert between `RESPValue` and native types.

`Array`, `Data`, `Float`, `Double`, `FixedWidthInteger`, `String`, and of course `RESPValue` all conform in this package.
