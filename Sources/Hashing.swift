//
//  Hashing.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-22.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

private let factor = Int(truncatingBitPattern: (MemoryLayout<Int>.size == 8 ? 1099511628211 : 16777619) as UInt64)

extension Int {
    static let baseHash = Int(truncatingBitPattern: (MemoryLayout<Int>.size == 8 ? 14695981039346656037 : 2166136261) as UInt64)


    /// Combine this hash value with the hash value of `other`,
    /// using the [FNV-1a hash algorithm][fnv].
    ///
    /// [fnv]: http://www.isthe.com/chongo/tech/comp/fnv/
    func mixed<H: Hashable>(with other: H) -> Int {
        return mixed(withHash: other.hashValue)
    }

    /// Combine this hash value with another hash value into a single hash value,
    /// using the [FNV-1a hash algorithm][fnv].
    ///
    /// [fnv]: http://www.isthe.com/chongo/tech/comp/fnv/
    func mixed(withHash hash: Int) -> Int {
        var result = self
        var value = hash
        for _ in 0 ..< MemoryLayout<Int>.size {
            let byte = value & 0xFF
            value = value >> 8
            result = result ^ byte
            result = result &* factor
        }
        return result
    }
}

func combinedHashes<S: Sequence>(_ values: S) -> Int where S.Iterator.Element == Int {
    var hash = Int.baseHash
    for value in values {
        hash = hash.mixed(withHash: value)
    }
    return hash
}

func combinedHashes(_ values: Int...) -> Int {
    return combinedHashes(values)
}
