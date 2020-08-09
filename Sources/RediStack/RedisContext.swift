//===----------------------------------------------------------------------===//
//
// This source file is part of the RediStack open source project
//
// Copyright (c) 2020 RediStack project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of RediStack project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct Logging.Logger

// Right now this is just a typealias of Logger
// however, after https://forums.swift.org/t/the-context-passing-problem/39162
// the future direction is to have a more complex 'baggage context' type that will be passed around
// so in order to be "future thinking" we create this typealias and interally refer to this passing of configuration
// as context

internal typealias Context = Logging.Logger
