import NIO

/// `ChannelInboundHandler` that handles the responsibility of coordinating incoming and outgoing messages
/// on a particular connection to Redis.
internal final class RedisMessenger: ChannelInboundHandler {
    /// See `ChannelInboundHandler.InboundIn`
    public typealias InboundIn = RedisData

    /// See `ChannelInboundHandler.OutboundOut`
    public typealias OutboundOut = RedisData

    /// Queue of promises waiting to receive an incoming response value from a outgoing message.
    private var waitingResponseQueue: [EventLoopPromise<InboundIn>]
    /// Queue of unsent outgoing messages, with the oldest objects at the end of the array.
    private var outgoingMessageQueue: [OutboundOut]

    /// This handler's event loop.
    private let eventLoop: EventLoop

    /// Context used for writing outgoing messages with.
    private weak var outputContext: ChannelHandlerContext?

    /// Creates a new handler that works on the specified `EventLoop`.
    public init(on eventLoop: EventLoop) {
        self.waitingResponseQueue = []
        self.outgoingMessageQueue = []
        self.eventLoop = eventLoop
    }

    /// See `ChannelInboundHandler.channelActive(ctx:)`
    public func channelActive(ctx: ChannelHandlerContext) {
        outputContext = ctx
        _flushOutgoingQueue()
    }

    /// See `ChannelInboundHandler.errorCaught(ctx:error:)`
    public func errorCaught(ctx: ChannelHandlerContext, error: Error) {
        guard let leadPromise = waitingResponseQueue.last else {
            return assertionFailure("Received unexpected error while idle: \(error.localizedDescription)")
        }
        leadPromise.fail(error: error)
    }

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

    /// Adds a complete message encoded as `RedisData` to the queue and returns an `EventLoopFuture` that resolves
    /// the response from Redis.
    func enqueue(_ output: OutboundOut) -> EventLoopFuture<InboundIn> {
        // ensure that we are on the event loop before modifying our data
        guard eventLoop.inEventLoop else {
            return eventLoop.submit { }.then { return self.enqueue(output) }
        }

        // add the new output to the writing queue at the front
        outgoingMessageQueue.insert(output, at: 0)

        // every outgoing message is expected to receive some form of response, so build
        // the context in the readQueue that we resolve with the response
        let promise = eventLoop.makePromise(of: InboundIn.self)
        waitingResponseQueue.insert(promise, at: 0)

        // if we have a context for writing, flush the outgoing queue
        outputContext?.eventLoop.execute {
            self._flushOutgoingQueue()
        }

        return promise.futureResult
    }

    /// Writes all queued outgoing messages to the channel.
    func _flushOutgoingQueue() {
        guard let context = outputContext else { return }

        while let output = outgoingMessageQueue.popLast() {
            context.write(wrapOutboundOut(output), promise: nil)
            context.flush()
        }
    }
}
