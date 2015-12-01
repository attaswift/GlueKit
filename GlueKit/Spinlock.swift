//
//  Spinlock.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-01.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

/// A simple spinlock based on OSSpinLock.
internal struct Spinlock {
    private var lock: OSSpinLock = OS_SPINLOCK_INIT

    mutating func locked<Result>(block: Void->Result) -> Result {
        OSSpinLockLock(&lock)
        let result = block()
        OSSpinLockUnlock(&lock)
        return result
    }
}
