//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2023 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@_spi(RESP3) import RediStack
import Foundation
import NIOCore
import NIOEmbedded

func runRESPProtocol() throws {
    let channel = EmbeddedChannel()
    try channel.pipeline.addBaseRedisHandlers().wait()

    // Precalculate the server response
    try channel.connect(to: .init(unixDomainSocketPath: "/fakeserver")).wait()
    var redisReplyBuffer = ByteBuffer()
    let serverValue = "Hello, world"
    let replyValue = RESPValue.simpleString(ByteBuffer(string: serverValue))
    RESPTranslator().write(replyValue, into: &redisReplyBuffer)
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

    guard case .clean = try channel.finish() else {
        fatalError("Test didn't exit cleanly")
    }
}
