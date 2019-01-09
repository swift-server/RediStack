import NIO

/// `ChannelInboundHandler` that is responsible for coordinating incoming and outgoing messages on a particular
/// connection to Redis.
internal final class RedisMessenger {
    private let eventLoop: EventLoop

    /// Context to be used for writing outgoing messages with.
    private var channelContext: ChannelHandlerContext?

    /// Queue of promises waiting to receive an incoming response value from an outgoing message.
    private var waitingResponseQueue: [EventLoopPromise<RESPValue>]
    /// Queue of unset outgoing messages, with the oldest messages at the end of the array.
    private var outgoingMessageQueue: [RESPValue]

    /// Creates a new handler that works on the specified `EventLoop`.
    init(on eventLoop: EventLoop) {
        self.waitingResponseQueue = []
        self.outgoingMessageQueue = []
        self.eventLoop = eventLoop
    }
    
    /// Adds a complete message encoded as `RESPValue` to the queue and returns an `EventLoopFuture` that resolves
    /// the response from Redis.
    func enqueue(_ output: RESPValue) -> EventLoopFuture<RESPValue> {
        // ensure that we are on the event loop before modifying our data
        guard eventLoop.inEventLoop else {
            return eventLoop.submit({}).then { return self.enqueue(output) }
        }

        // add the new output to the writing queue at the front
        outgoingMessageQueue.insert(output, at: 0)

        // every outgoing message is expected to receive some form of response, so create a promise that we'll resolve
        // with the response
        let promise = eventLoop.makePromise(of: RESPValue.self)
        waitingResponseQueue.insert(promise, at: 0)

        // if we have a context for writing, flush the outgoing queue
        channelContext?.eventLoop.execute {
            self._flushOutgoingQueue()
        }

        return promise.futureResult
    }

    /// Writes all queued outgoing messages to the channel.
    func _flushOutgoingQueue() {
        guard let context = channelContext else { return }

        while let output = outgoingMessageQueue.popLast() {
            context.write(wrapOutboundOut(output), promise: nil)
            context.flush()
        }
    }
}

// MARK: ChannelInboundHandler

extension RedisMessenger: ChannelInboundHandler {
    /// See `ChannelInboundHandler.InboundIn`
    public typealias InboundIn = RESPValue

    /// See `ChannelInboundHandler.OutboundOut`
    public typealias OutboundOut = RESPValue

    /// Invoked by NIO when the channel for this handler has become active, receiving a context that is ready to
    /// send messages.
    ///
    /// Any queued messages will be flushed at this point.
    /// See `ChannelInboundHandler.channelActive(ctx:)`
    public func channelActive(ctx: ChannelHandlerContext) {
        channelContext = ctx
        _flushOutgoingQueue()
    }

    /// Invoked by NIO when an error was thrown earlier in the response chain. The waiting promise at the front
    /// of the queue will be failed with the error.
    /// See `ChannelInboundHandler.errorCaught(ctx:error:)`
    public func errorCaught(ctx: ChannelHandlerContext, error: Error) {
        guard let leadPromise = waitingResponseQueue.last else {
            return assertionFailure("Received unexpected error while idle: \(error.localizedDescription)")
        }
        leadPromise.fail(error: error)
    }

    /// Invoked by NIO when a read has been fired from earlier in the response chain. This forwards the unwrapped
    /// `RESPValue` to the response at the front of the queue.
    /// See `ChannelInboundHandler.channelRead(ctx:data:)`
    public func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        let input = unwrapInboundIn(data)

        guard let leadPromise = waitingResponseQueue.last else {
            return assertionFailure("Read triggered with an empty input queue! Ignoring: \(input)")
        }

        let popped = waitingResponseQueue.popLast()
        assert(popped != nil)

        leadPromise.succeed(result: input)
    }
}
