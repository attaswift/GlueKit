//
//  Locks.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-01.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

internal protocol Lockable {
    func lock()
    func unlock()
    func tryLock() -> Bool
    func withLock<Result>(_ block: (Void) -> Result) -> Result
}

extension Lockable {
    func withLock<Result>(_ block: (Void) -> Result) -> Result {
        lock()
        defer { unlock() }
        return block()
    }
}

extension NSLock: Lockable {
    internal convenience init(name: String) {
        self.init()
        self.name = name
    }
}

extension NSRecursiveLock: Lockable {
    internal convenience init(name: String) {
        self.init()
        self.name = name
    }
}

struct Lock: Lockable {
    private let _lock: LockImplementation

    init() {
        if #available(macOS 10.12, iOS 10, watchOS 3.0, tvOS 10.0, *) {
            self._lock = UnfairLock()
        }
        else {
            self._lock = PosixMutex()
        }
    }
    func lock() { _lock.lock() }
    func unlock() { _lock.unlock() }
    func tryLock() -> Bool { return _lock.tryLock() }
}

private class LockImplementation: Lockable {
    init() {}

    func lock() {}
    func unlock() {}
    func tryLock() -> Bool { return true }
}

@available(macOS 10.12, iOS 10, watchOS 3.0, tvOS 10.0, *)
private final class UnfairLock: LockImplementation {
    private var _lock = os_unfair_lock()

    override func lock() {
        os_unfair_lock_lock(&_lock)
    }

    override func unlock() {
        os_unfair_lock_unlock(&_lock)
    }

    override func tryLock() -> Bool {
        return os_unfair_lock_trylock(&_lock)
    }
}

private final class PosixMutex: LockImplementation {
    private var mutex = pthread_mutex_t()

    override init() {
        let result = pthread_mutex_init(&mutex, nil)
        if result != 0 {
            preconditionFailure("pthread_mutex_init returned \(result)")
        }
    }

    deinit {
        let result = pthread_mutex_destroy(&mutex)
        if result != 0 {
            preconditionFailure("pthread_mutex_destroy returned \(result)")
        }
    }

    override func lock() {
        let result = pthread_mutex_lock(&mutex)
        if result != 0 {
            preconditionFailure("pthread_mutex_lock returned \(result)")
        }
    }

    override func unlock() {
        let result = pthread_mutex_unlock(&mutex)
        if result != 0 {
            preconditionFailure("pthread_mutex_unlock returned \(result)")
        }
    }

    override func tryLock() -> Bool {
        let result = pthread_mutex_trylock(&mutex)
        switch result {
        case 0: return true
        case EBUSY: return false
        default:
            preconditionFailure("pthread_mutex_trylock returned \(result)")
        }
        return true
    }
}
