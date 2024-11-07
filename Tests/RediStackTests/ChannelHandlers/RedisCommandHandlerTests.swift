//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2019-2020 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Atomics
import NIOCore
import NIOEmbedded
import NIOPosix
import XCTest

@testable import RediStack

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

    func testCloseIsTriggeredOnceCommandQueueIsEmpty() {
        let loop = EmbeddedEventLoop()
        let channel = EmbeddedChannel(handler: RedisCommandHandler(), loop: loop)

        XCTAssertNoThrow(try channel.connect(to: .init(unixDomainSocketPath: "/foo")).wait())
        XCTAssertTrue(channel.isActive)

        let getFoo = RESPValue.array([.bulkString(.init(string: "GET")), .bulkString(.init(string: "foo"))])
        let promiseFoo = loop.makePromise(of: RESPValue.self)
        let commandFoo = RedisCommand(message: getFoo, responsePromise: promiseFoo)
        XCTAssertNoThrow(try channel.writeOutbound(commandFoo))
        XCTAssertEqual(try channel.readOutbound(as: RESPValue.self), getFoo)

        let getBar = RESPValue.array([.bulkString(.init(string: "GET")), .bulkString(.init(string: "bar"))])
        let promiseBar = loop.makePromise(of: RESPValue.self)
        let commandBar = RedisCommand(message: getBar, responsePromise: promiseBar)
        XCTAssertNoThrow(try channel.writeOutbound(commandBar))
        XCTAssertEqual(try channel.readOutbound(as: RESPValue.self), getBar)

        let getBaz = RESPValue.array([.bulkString(.init(string: "GET")), .bulkString(.init(string: "baz"))])
        let promiseBaz = loop.makePromise(of: RESPValue.self)
        let commandBaz = RedisCommand(message: getBaz, responsePromise: promiseBaz)
        XCTAssertNoThrow(try channel.writeOutbound(commandBaz))
        XCTAssertEqual(try channel.readOutbound(as: RESPValue.self), getBaz)

        let gracefulClosePromise = loop.makePromise(of: Void.self)
        let channelCloseHitCounter = ManagedAtomic<Int>(0)
        gracefulClosePromise.futureResult.whenComplete { _ in
            channelCloseHitCounter.wrappingIncrement(ordering: .relaxed)
        }
        channel.triggerUserOutboundEvent(RedisGracefulConnectionCloseEvent(), promise: gracefulClosePromise)
        XCTAssertEqual(channelCloseHitCounter.load(ordering: .relaxed), 0)

        let fooResponse = RESPValue.simpleString(.init(string: "fooresult"))
        XCTAssertNoThrow(try channel.writeInbound(fooResponse))
        XCTAssertTrue(channel.isActive)
        XCTAssertEqual(channelCloseHitCounter.load(ordering: .relaxed), 0)
        XCTAssertEqual(try promiseFoo.futureResult.wait(), fooResponse)

        let barResponse = RESPValue.simpleString(.init(string: "barresult"))
        XCTAssertNoThrow(try channel.writeInbound(barResponse))
        XCTAssertTrue(channel.isActive)
        XCTAssertEqual(channelCloseHitCounter.load(ordering: .relaxed), 0)
        XCTAssertEqual(try promiseBar.futureResult.wait(), barResponse)

        let bazResponse = RESPValue.simpleString(.init(string: "bazresult"))
        XCTAssertNoThrow(try channel.writeInbound(bazResponse))
        XCTAssertEqual(try promiseBaz.futureResult.wait(), bazResponse)
        XCTAssertFalse(channel.isActive)
        XCTAssertEqual(channelCloseHitCounter.load(ordering: .relaxed), 1)
        XCTAssertNoThrow(try gracefulClosePromise.futureResult.wait())
    }

    func testCloseIsTriggeredRightAwayIfCommandQueueIsEmpty() {
        let loop = EmbeddedEventLoop()
        let channel = EmbeddedChannel(handler: RedisCommandHandler(), loop: loop)
        XCTAssertNoThrow(try channel.connect(to: .init(unixDomainSocketPath: "/foo")).wait())
        XCTAssertTrue(channel.isActive)

        let gracefulClosePromise = loop.makePromise(of: Void.self)
        let gracefulCloseHitCounter = ManagedAtomic<Int>(0)
        gracefulClosePromise.futureResult.whenComplete { _ in
            gracefulCloseHitCounter.wrappingIncrement(ordering: .relaxed)
        }
        channel.triggerUserOutboundEvent(RedisGracefulConnectionCloseEvent(), promise: gracefulClosePromise)
        XCTAssertFalse(channel.isActive)
        XCTAssertEqual(gracefulCloseHitCounter.load(ordering: .relaxed), 1)

        let getBar = RESPValue.array([.bulkString(.init(string: "GET")), .bulkString(.init(string: "bar"))])
        let promiseBar = loop.makePromise(of: RESPValue.self)
        let commandBar = RedisCommand(message: getBar, responsePromise: promiseBar)
        channel.write(commandBar, promise: nil)
        XCTAssertThrowsError(try promiseBar.futureResult.wait()) {
            XCTAssertEqual($0 as? RedisClientError, .connectionClosed)
        }
    }
}

private final class RemoteCloseHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        context.close(promise: nil)
    }
}
