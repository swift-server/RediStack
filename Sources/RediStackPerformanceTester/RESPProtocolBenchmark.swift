import RediStack
import RESP3
import Foundation
import NIOCore
import NIOEmbedded

func benchmarkRESPProtocol() throws {
    let channel = EmbeddedChannel()
    try channel.pipeline.addBaseRedisHandlers().wait()

    // Precalculate the server response
    try channel.connect(to: .init(unixDomainSocketPath: "/fakeserver")).wait()
    var redisReplyBuffer = ByteBuffer()
    let serverValue = "Hello, world"
    let replyValue = RESPValue.simpleString(ByteBuffer(string: serverValue))
    RESPTranslator().write(replyValue, into: &redisReplyBuffer)

    try benchmark {
        let promise = channel.eventLoop.makePromise(of: RESPValue.self)

        // Client sends a command
        try channel.writeOutbound(RedisCommand(
            message: .array([
                .bulkString(ByteBuffer(string: "GET")),
                .bulkString(ByteBuffer(string: "welcome")),
            ]),
            responsePromise: promise
        ))

        // Server reads the command
        _ = try channel.readOutbound(as: ByteBuffer.self)
        // Server replies
        try channel.writeInbound(redisReplyBuffer)

        // Client reads the reply
        let serverReply = try promise.futureResult.wait()
        guard serverReply.string == serverValue else {
            fatalError("Invalid test result")
        }
    }

    guard case .clean = try channel.finish() else {
        fatalError("Test didn't exit cleanly")
    }
}
