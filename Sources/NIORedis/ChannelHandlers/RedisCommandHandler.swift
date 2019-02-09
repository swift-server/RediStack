import Foundation
import NIO

/// A context for `RedisCommandHandler` to operate within.
public struct RedisCommandContext {
    /// A full command keyword and arguments stored as a single `RESPValue`.
    public let command: RESPValue
    /// A promise expected to be fulfilled with the `RESPValue` response to the command from Redis.
    public let responsePromise: EventLoopPromise<RESPValue>

    public init(command: RESPValue, promise: EventLoopPromise<RESPValue>) {
        self.command = command
        self.responsePromise = promise
    }
}

/// A `ChannelDuplexHandler` that works with `RedisCommandContext`s to send commands and forward responses.
open class RedisCommandHandler {
    /// Queue of promises waiting to receive a response value from a sent command.
    private var commandResponseQueue: [EventLoopPromise<RESPValue>]

    public init() {
        self.commandResponseQueue = []
    }
}

// MARK: ChannelInboundHandler

extension RedisCommandHandler: ChannelInboundHandler {
    /// See `ChannelInboundHandler.InboundIn`
    public typealias InboundIn = RESPValue

    /// Invoked by NIO when an error has been thrown. The command response promise at the front of the queue will be
    /// failed with the error.
    ///
    /// See `ChannelInboundHandler.errorCaught(ctx:error:)`
    public func errorCaught(ctx: ChannelHandlerContext, error: Error) {
        guard let leadPromise = commandResponseQueue.last else {
            return assertionFailure("Received unexpected error while idle: \(error.localizedDescription)")
        }
        leadPromise.fail(error)
    }

    /// Invoked by NIO when a read has been fired from earlier in the response chain. This forwards the unwrapped
    /// `RESPValue` to the promise awaiting a response at the front of the queue.
    ///
    /// See `ChannelInboundHandler.channelRead(ctx:data:)`
    public func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        let value = unwrapInboundIn(data)

        guard let leadPromise = commandResponseQueue.last else {
            return assertionFailure("Read triggered with an empty promise queue! Ignoring: \(value)")
        }

        let popped = commandResponseQueue.popLast()
        assert(popped != nil)

        switch value {
        case .error(let e): leadPromise.fail(e)
        default: leadPromise.succeed(value)
        }
    }
}

// MARK: ChannelOutboundHandler

extension RedisCommandHandler: ChannelOutboundHandler {
    /// See `ChannelOutboundHandler.OutboundIn`
    public typealias OutboundIn = RedisCommandContext
    /// See `ChannelOutboundHandler.OutboundOut`
    public typealias OutboundOut = RESPValue

    /// Invoked by NIO when a `write` has been requested on the `Channel`.
    /// This unwraps a `RedisCommandContext`, retaining a callback to forward a response to later, and forwards
    /// the underlying command data further into the pipeline.
    ///
    /// See `ChannelOutboundHandler.write(ctx:data:promise:)`
    public func write(ctx: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let context = unwrapOutboundIn(data)
        commandResponseQueue.insert(context.responsePromise, at: 0)
        ctx.write(wrapOutboundOut(context.command), promise: promise)
    }
}
