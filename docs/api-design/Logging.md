# RediStack Logging

Subsystem logging is a form of art, where the proper balance of logging too much is weighed against the need for specific information to not be lost to developers.

Sometimes, a subsystem log is what turns a 3 hour debug session into a 5 minute one.

## Categories of Logs

**RediStack** approaches logging with the mindset of "user-space" versus "system-space" logs.

- `system-space` being logs that are triggered from static contexts
  - examples include trace statements or precondition failures
- `user-space` being logs that are triggered by a user event
  - examples include requesting a pool connection or sending a Redis command

From this mindset, the design is impacted in two ways:

1. Connections (and pools) have a "static" logger instance for their entire lifetime to log in `system-space`
1. Regular user-driven events can provide a custom logger instance that is tied to the lifetime of the event, hence `user-space`

In both cases, the logger can be provided by a developer to have a custom label and attached metadata for each log statement.

However, in the first case the logger is configured _once_ at initialization and is bound to the lifetime of the pool or individual connection.

In order to cut down on the verbosity of both the definitions of methods and at the call site, **RediStack** employs the use of a pattern referred
to as [_Protocol-based Context Passing_](https://forums.swift.org/t/the-context-passing-problem/39162).

```swift
// example code, may not reflect current implementation

let myCustomLogger = ...
let connection = ...
// will use this logger for all 'user-space' logs generated while serving this command
connection.ping(logger: myCustomLogger)
```

## Log Guidelines

1. Prefer logging at `trace` levels
1. Prefer `debug` for any log that contains metadata, especially complex ones like structs or classes
  - exceptions to this guideline may include metadata such as object IDs that are triggering the logs
1. Dynamic values SHOULD be attached as metadata rather than string interpolated
1. All log metadata keys SHOULD be added to the `RedisLogging` namespace
1. Log messages SHOULD be in all lowercase, with no punctuation preferred
  - if a Redis command keyword (such as `QUIT`) is in the log message, it MUST be in all caps
1. `warning` logs SHOULD be reserved for situations that could lead to `error` or `critical` conditions
  - this MAY include leaks or bad state
1. Only use `error` in situations where the error cannot be expressed by the language, such as by throwing an error or failing `EventLoopFuture`s.
  - this is to avoid high severity logs that developers cannot control and must create filtering mechanisms if they want to ignore emitted logs from **RediStack**
1. Log a `critical` message before any `preconditionFailure` or `fatalError`

### Metadata

1. All keys SHOULD have the `rdstk` prefix to avoid collisions
1. Public metadata keys SHOULD be 16 characters or less to avoid as many String allocations as possible
1. Keys SHOULD be computed properties to avoid memory costs
