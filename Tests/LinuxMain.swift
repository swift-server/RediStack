//===----------------------------------------------------------------------===//
//
// This source file is part of the NIORedis open source project
//
// Copyright (c) 2019 NIORedis project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of NIORedis project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import XCTest

import NIORedisTests

var tests = [XCTestCaseEntry]()
tests += NIORedisTests.allTests()
XCTMain(tests)
