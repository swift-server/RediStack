//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2019-2022 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOCore
import NIOPosix
@testable import RediStack
import XCTest

final class RedisCommandHandlerTests: XCTestCase {
    func test_whenRemoteConnectionCloses_handlerFailsCommandQueue() throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { try? group.syncShutdownGracefully() }
        let socketAddress = try SocketAddress.makeAddressResolvingHost("localhost", port: 8080)
        
        let server = try ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.socket(.init(SOL_SOCKET), .init(SO_REUSEADDR)), value: 1)
            .childChannelInitializer { $0.pipeline.addHandler(RemoteCloseHandler()) }
            .bind(to: socketAddress)
            .wait()
        defer { try? server.close().wait() }
        
        let connection = try RedisConnection.make(
            configuration: .init(hostname: "localhost", port: 8080),
            boundEventLoop: group.next()
        ).wait()
        defer { try? connection.close().wait() }
        
        XCTAssertThrowsError(try connection.ping().wait()) {
            guard let error = $0 as? RedisClientError else {
                XCTFail("Wrong error type thrown")
                return
            }
            XCTAssertEqual(error, .connectionClosed)
        }
    }
}

private final class RemoteCloseHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        context.close(promise: nil)
    }
}
