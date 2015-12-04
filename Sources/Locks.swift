//
//  Locks.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-01.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

internal protocol Lock {
    mutating func locked<Result>(@noescape block: Void->Result) -> Result
}

/// A simple lock based on OSSpinLock.
internal struct Spinlock: Lock {
    private var lock: OSSpinLock = OS_SPINLOCK_INIT

    mutating func locked<Result>(@noescape block: Void->Result) -> Result {
        OSSpinLockLock(&lock)
        let result = block()
        OSSpinLockUnlock(&lock)
        return result
    }
}

extension NSLocking {
    internal func locked<Result>(@noescape block: Void->Result) -> Result {
        self.lock()
        defer { self.unlock() }
        return block()
    }
}

extension NSLock {
    internal convenience init(name: String) {
        self.init()
        self.name = name
    }
}

extension NSRecursiveLock {
    internal convenience init(name: String) {
        self.init()
        self.name = name
    }
}
