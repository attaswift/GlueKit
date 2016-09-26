//
//  Atomics.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-27.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

class AtomicBool {
    private let lock = NSLock()
    private var value: Bool

    init(_ value: Bool = false) {
        self.value = value
    }

    @discardableResult
    func set(_ value: Bool) -> Bool {
        return lock.withLock {
            let old = self.value
            self.value = value
            return old
        }
    }

    func get() -> Bool {
        return lock.withLock {
            return value
        }
    }
}

