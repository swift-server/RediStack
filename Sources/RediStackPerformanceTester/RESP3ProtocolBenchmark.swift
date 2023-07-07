import RediStack
import RESP3
import Foundation
import NIOCore
import NIOEmbedded

func benchmarkRESP3Protocol() throws {
    let channel = EmbeddedChannel()

    // Precalculate the server response
    try channel.connect(to: .init(unixDomainSocketPath: "/fakeserver")).wait()
    let serverReply = "Hello, world"
    let redisReplyBuffer = ByteBuffer(string: "$\(serverReply.count)\r\n\(serverReply)\r\n")

    try benchmark {
        // Client sends a command
        // GET welcome
        // TODO: Replace when we get RESP3 serialization
        try channel.writeOutbound(ByteBuffer(string: "*2\r\n$3\r\nGET\r\n$7\r\nwelcome\r\n"))

        // Server reads the command
        _ = try channel.readOutbound(as: ByteBuffer.self)
        // Server replies
        try channel.writeInbound(redisReplyBuffer)

        // Client reads the reply
        guard var serverReplyBuffer = try channel.readInbound(as: ByteBuffer.self) else {
            fatalError("Missing reply")
        }
        
        guard case .blobString(var blobString) = try RESP3Token(consuming: &serverReplyBuffer)?.value else {
            fatalError("Invalid reply")
        }

        guard blobString.readString(length: blobString.readableBytes) == serverReply else {
            fatalError("Invalid test result")
        }
    }

    guard case .clean = try channel.finish() else {
        fatalError("Test didn't exit cleanly")
    }
}
