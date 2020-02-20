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

extension Array {
    /// Initializes an empty array, reserving the desired `initialCapacity`.
    /// - Parameter initialCapacity: The desired element size the array should start with.
    internal init(initialCapacity: Int) {
        self = []
        self.reserveCapacity(initialCapacity)
    }
}
