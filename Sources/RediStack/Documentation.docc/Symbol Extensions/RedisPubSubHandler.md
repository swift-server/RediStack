# ``RediStack/RedisPubSubHandler``

``RedisPubSubEventReceiver`` closures are added and removed using methods directly on an instance of this handler.

When a receiver is added or removed, the handler will send the appropriate subscribe or unsubscribe message to Redis so that the connection
reflects the local Channel state.

## ChannelInboundHandler
This handler is designed to be placed _before_ a ``RedisCommandHandler`` so that it can intercept Pub/Sub messages and dispatch them to the appropriate
receiver.

If a response is not in the Pub/Sub message format as specified by Redis, then it is treated as a normal Redis command response and sent further into
the pipeline so that eventually a ``RedisCommandHandler`` can process it.

## ChannelOutboundHandler
This handler is what is defined as a "transparent" `NIO.ChannelOutboundHandler` in that it does absolutely nothing except forward outgoing commands
in the pipeline.

The reason why this handler needs to conform to this protocol at all, is that subscribe and unsubscribe commands are executed outside of a normal
`NIO.Channel.write(_:)` cycle, as message receivers aren't command arguments and need to be stored.

All of this is outside the responsibility of the ``RedisCommandHandler``,
so the ``RedisPubSubHandler`` uses its own `NIO.ChannelHandlerContext` being before the command handler to short circuit the pipeline.

## RemovableChannelHandler
As a connection can move in and out of "PubSub mode", this handler can be added and removed from a `NIO.ChannelPipeline` as needed.

When the handler has received a `removeHandler(context:removalToken:)` request, it will remove itself immediately.

## Topics

### Managing Subscriptions

- ``RedisSubscriptionTarget``
- ``addSubscription(for:receiver:)``
- ``removeSubscription(for:)``

### Pub/Sub Events

- ``RedisPubSubEvent``
- ``RedisPubSubEventReceiver``
