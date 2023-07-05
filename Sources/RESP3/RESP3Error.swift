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

enum RESP3Error: Error, Equatable {
    case unexpectedEndOfData
    case missingCRLF
    case dataMalformed
    case invalidType(UInt8)
    case tooDepplyNestedAggregatedTypes
}
