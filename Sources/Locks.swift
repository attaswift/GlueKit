//
//  Locks.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-01.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

internal protocol Lock {
    mutating func lock()
    mutating func unlock()
    mutating func tryLock() -> Bool
    mutating func withLock<Result>(@noescape block: Void->Result) -> Result
}

extension Lock {
    mutating func withLock<Result>(@noescape block: Void->Result) -> Result {
        lock()
        defer { unlock() }
        return block()
    }
}

internal struct RawMutex: Lock {
    private var mutex = pthread_mutex_t()

    init() {
        let result = pthread_mutex_init(&mutex, nil)
        if result != 0 {
            preconditionFailure("pthread_mutex_init returned \(result)")
        }
    }

    mutating func destroy() {
        let result = pthread_mutex_destroy(&mutex)
        if result != 0 {
            preconditionFailure("pthread_mutex_destroy returned \(result)")
        }
    }

    mutating func lock() {
        let result = pthread_mutex_lock(&mutex)
        if result != 0 {
            preconditionFailure("pthread_mutex_lock returned \(result)")
        }
    }

    mutating func unlock() {
        let result = pthread_mutex_unlock(&mutex)
        if result != 0 {
            preconditionFailure("pthread_mutex_unlock returned \(result)")
        }
    }

    mutating func tryLock() -> Bool {
        let result = pthread_mutex_trylock(&mutex)
        switch result {
        case 0: return true
        case EBUSY: return false
        default:
            preconditionFailure("pthread_mutex_trylock returned \(result)")
        }
    }
}

internal final class Mutex: Lock {
    private var mutex: RawMutex

    init() {
        mutex = RawMutex()
    }

    deinit {
        mutex.destroy()
    }

    func lock() {
        mutex.lock()
    }

    func unlock() {
        mutex.unlock()
    }

    func tryLock() -> Bool {
        return mutex.tryLock()
    }

    func withLock<Result>(@noescape block: Void->Result) -> Result {
        lock()
        defer { unlock() }
        return block()
    }
}

extension NSLock: Lock {
    internal convenience init(name: String) {
        self.init()
        self.name = name
    }
}

extension NSRecursiveLock: Lock {
    internal convenience init(name: String) {
        self.init()
        self.name = name
    }
}
