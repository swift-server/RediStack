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

// The following has been pulled from the CryptoSwift project for the purposes of providing a SHA1 implementation
// without relying on an OpenSSL solution which has its own set of problems.
// Modifications made:
//   Visibility modifiers (public, internal, etc.) have been lowered to ensure the SHA1 code is an implementation detail.
//   Return statements were added for Swift 5 compatability.
//   Only the necessary code to compile the implementation were copied over.

//
//  CryptoSwift
//
//  Copyright (C) 2014-2017 Marcin Krzyżanowski <marcin@krzyzanowskim.com>
//  This software is provided 'as-is', without any express or implied warranty.
//
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
//  - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  - This notice may not be removed or altered from any source or binary distribution.
//

extension Array {
  init(reserveCapacity: Int) {
    self = Array<Element>()
    self.reserveCapacity(reserveCapacity)
  }

  var slice: ArraySlice<Element> {
    return self[self.startIndex ..< self.endIndex]
  }
}

extension Array where Element == UInt8 {
    internal func toHexString() -> String {
      return `lazy`.reduce(into: "") {
        var s = String($1, radix: 16)
        if s.count == 1 {
          s = "0" + s
        }
        $0 += s
      }
    }
}

extension UInt32 {
  @_specialize(exported: true, where T == ArraySlice<UInt8>)
  init<T: Collection>(bytes: T) where T.Element == UInt8, T.Index == Int {
    self = UInt32(bytes: bytes, fromIndex: bytes.startIndex)
  }

  @_specialize(exported: true, where T == ArraySlice<UInt8>)
  init<T: Collection>(bytes: T, fromIndex index: T.Index) where T.Element == UInt8, T.Index == Int {
    if bytes.isEmpty {
      self = 0
      return
    }

    let count = bytes.count

    let val0 = count > 0 ? UInt32(bytes[index.advanced(by: 0)]) << 24 : 0
    let val1 = count > 1 ? UInt32(bytes[index.advanced(by: 1)]) << 16 : 0
    let val2 = count > 2 ? UInt32(bytes[index.advanced(by: 2)]) << 8 : 0
    let val3 = count > 3 ? UInt32(bytes[index.advanced(by: 3)]) : 0

    self = val0 | val1 | val2 | val3
  }
}

@_transparent
func rotateLeft(_ value: UInt32, by: UInt32) -> UInt32 {
  return ((value << by) & 0xffffffff) | (value >> (32 - by))
}

/**
 ISO/IEC 9797-1 Padding method 2.
 Add a single bit with value 1 to the end of the data.
 If necessary add bits with value 0 to the end of the data until the padded data is a multiple of blockSize.
 - parameters:
 - blockSize: Padding size in bytes.
 - allowance: Excluded trailing number of bytes.
 */
@inline(__always)
func bitPadding(to data: inout Array<UInt8>, blockSize: Int, allowance: Int = 0) {
  let msgLength = data.count
  // Step 1. Append Padding Bits
  // append one bit (UInt8 with one bit) to message
  data.append(0x80)

  // Step 2. append "0" bit until message length in bits ≡ 448 (mod 512)
  let max = blockSize - allowance // 448, 986
  if msgLength % blockSize < max { // 448
    data += Array<UInt8>(repeating: 0, count: max - 1 - (msgLength % blockSize))
  } else {
    data += Array<UInt8>(repeating: 0, count: blockSize + max - 1 - (msgLength % blockSize))
  }
}

/// Array of bytes. Caution: don't use directly because generic is slow.
///
/// - parameter value: integer value
/// - parameter length: length of output array. By default size of value type
///
/// - returns: Array of bytes
@_specialize(exported: true, where T == Int)
@_specialize(exported: true, where T == UInt)
@_specialize(exported: true, where T == UInt8)
@_specialize(exported: true, where T == UInt16)
@_specialize(exported: true, where T == UInt32)
@_specialize(exported: true, where T == UInt64)
func arrayOfBytes<T: FixedWidthInteger>(value: T, length totalBytes: Int = MemoryLayout<T>.size) -> Array<UInt8> {
  let valuePointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
  valuePointer.pointee = value

  let bytesPointer = UnsafeMutablePointer<UInt8>(OpaquePointer(valuePointer))
  var bytes = Array<UInt8>(repeating: 0, count: totalBytes)
  for j in 0..<min(MemoryLayout<T>.size, totalBytes) {
    bytes[totalBytes - 1 - j] = (bytesPointer + j).pointee
  }

  valuePointer.deinitialize(count: 1)
  valuePointer.deallocate()

  return bytes
}

extension FixedWidthInteger {
  @_transparent
  func bytes(totalBytes: Int = MemoryLayout<Self>.size) -> Array<UInt8> {
    return arrayOfBytes(value: self.littleEndian, length: totalBytes)
    // TODO: adjust bytes order
    // var value = self.littleEndian
    // return withUnsafeBytes(of: &value, Array.init).reversed()
  }
}

struct BatchedCollectionIndex<Base: Collection> {
  let range: Range<Base.Index>
}

extension BatchedCollectionIndex: Comparable {
  static func == <Base>(lhs: BatchedCollectionIndex<Base>, rhs: BatchedCollectionIndex<Base>) -> Bool {
    return lhs.range.lowerBound == rhs.range.lowerBound
  }

  static func < <Base>(lhs: BatchedCollectionIndex<Base>, rhs: BatchedCollectionIndex<Base>) -> Bool {
    return lhs.range.lowerBound < rhs.range.lowerBound
  }
}

struct BatchedCollection<Base: Collection>: Collection {
  let base: Base
  let size: Int
  typealias Index = BatchedCollectionIndex<Base>
  private func nextBreak(after idx: Base.Index) -> Base.Index {
    return self.base.index(idx, offsetBy: self.size, limitedBy: self.base.endIndex) ?? self.base.endIndex
  }

  var startIndex: Index {
    return Index(range: self.base.startIndex..<self.nextBreak(after: self.base.startIndex))
  }

  var endIndex: Index {
    return Index(range: self.base.endIndex..<self.base.endIndex)
  }

  func index(after idx: Index) -> Index {
    return Index(range: idx.range.upperBound..<self.nextBreak(after: idx.range.upperBound))
  }

  subscript(idx: Index) -> Base.SubSequence {
    return self.base[idx.range]
  }
}

extension Collection {
  func batched(by size: Int) -> BatchedCollection<Self> {
    return BatchedCollection(base: self, size: size)
  }
}

@usableFromInline
internal final class SHA1 {
  static let digestLength: Int = 20 // 160 / 8
  static let blockSize: Int = 64
  fileprivate static let hashInitialValue: ContiguousArray<UInt32> = [0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476, 0xc3d2e1f0]

  fileprivate var accumulated = Array<UInt8>()
  fileprivate var processedBytesTotalCount: Int = 0
  fileprivate var accumulatedHash: ContiguousArray<UInt32> = SHA1.hashInitialValue

  internal init() {
  }

  internal func calculate(for bytes: Array<UInt8>) -> Array<UInt8> {
    do {
      return try update(withBytes: bytes.slice, isLast: true)
    } catch {
      return []
    }
  }

  fileprivate func process(block chunk: ArraySlice<UInt8>, currentHash hh: inout ContiguousArray<UInt32>) {
    // break chunk into sixteen 32-bit words M[j], 0 ≤ j ≤ 15, big-endian
    // Extend the sixteen 32-bit words into eighty 32-bit words:
    let M = UnsafeMutablePointer<UInt32>.allocate(capacity: 80)
    M.initialize(repeating: 0, count: 80)
    defer {
      M.deinitialize(count: 80)
      M.deallocate()
    }

    for x in 0..<80 {
      switch x {
        case 0...15:
          let start = chunk.startIndex.advanced(by: x * 4) // * MemoryLayout<UInt32>.size
          M[x] = UInt32(bytes: chunk, fromIndex: start)
        default:
          M[x] = rotateLeft(M[x - 3] ^ M[x - 8] ^ M[x - 14] ^ M[x - 16], by: 1)
      }
    }

    var A = hh[0]
    var B = hh[1]
    var C = hh[2]
    var D = hh[3]
    var E = hh[4]

    // Main loop
    for j in 0...79 {
      var f: UInt32 = 0
      var k: UInt32 = 0

      switch j {
        case 0...19:
          f = (B & C) | ((~B) & D)
          k = 0x5a827999
        case 20...39:
          f = B ^ C ^ D
          k = 0x6ed9eba1
        case 40...59:
          f = (B & C) | (B & D) | (C & D)
          k = 0x8f1bbcdc
        case 60...79:
          f = B ^ C ^ D
          k = 0xca62c1d6
        default:
          break
      }

      let temp = rotateLeft(A, by: 5) &+ f &+ E &+ M[j] &+ k
      E = D
      D = C
      C = rotateLeft(B, by: 30)
      B = A
      A = temp
    }

    hh[0] = hh[0] &+ A
    hh[1] = hh[1] &+ B
    hh[2] = hh[2] &+ C
    hh[3] = hh[3] &+ D
    hh[4] = hh[4] &+ E
  }
}

extension SHA1 {
  @discardableResult
  internal func update(withBytes bytes: ArraySlice<UInt8>, isLast: Bool = false) throws -> Array<UInt8> {
    self.accumulated += bytes

    if isLast {
      let lengthInBits = (processedBytesTotalCount + self.accumulated.count) * 8
      let lengthBytes = lengthInBits.bytes(totalBytes: 64 / 8) // A 64-bit representation of b

      // Step 1. Append padding
      bitPadding(to: &self.accumulated, blockSize: SHA1.blockSize, allowance: 64 / 8)

      // Step 2. Append Length a 64-bit representation of lengthInBits
      self.accumulated += lengthBytes
    }

    var processedBytes = 0
    for chunk in self.accumulated.batched(by: SHA1.blockSize) {
      if isLast || (self.accumulated.count - processedBytes) >= SHA1.blockSize {
        self.process(block: chunk, currentHash: &self.accumulatedHash)
        processedBytes += chunk.count
      }
    }
    self.accumulated.removeFirst(processedBytes)
    self.processedBytesTotalCount += processedBytes

    // output current hash
    var result = Array<UInt8>(repeating: 0, count: SHA1.digestLength)
    var pos = 0
    for idx in 0..<self.accumulatedHash.count {
      let h = self.accumulatedHash[idx]
      result[pos + 0] = UInt8((h >> 24) & 0xff)
      result[pos + 1] = UInt8((h >> 16) & 0xff)
      result[pos + 2] = UInt8((h >> 8) & 0xff)
      result[pos + 3] = UInt8(h & 0xff)
      pos += 4
    }

    // reset hash value for instance
    if isLast {
      self.accumulatedHash = SHA1.hashInitialValue
    }

    return result
  }
}
