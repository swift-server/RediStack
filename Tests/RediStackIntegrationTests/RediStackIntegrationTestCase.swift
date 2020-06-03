//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2019 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import class Foundation.ProcessInfo
import RediStackTestUtils

class RediStackIntegrationTestCase: RedisIntegrationTestCase {
    override var redisHostname: String {
        return ProcessInfo.processInfo.environment["REDIS_URL"] ?? "localhost"
    }
    override var redisPassword: String? {
        return ProcessInfo.processInfo.environment["REDIS_PW"]
    }
}

class RediStackConnectionPoolIntegrationTestCase: RedisConnectionPoolIntegrationTestCase {
    override var redisHostname: String {
        return ProcessInfo.processInfo.environment["REDIS_URL"] ?? "localhost"
    }
    override var redisPassword: String? {
        return ProcessInfo.processInfo.environment["REDIS_PW"]
    }
}
