//
//  Locks.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-01.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import Foundation

internal protocol Lockable {
    func lock()
    func unlock()
    func withLock<Result>(_ block: () throws -> Result) rethrows -> Result
}

extension Lockable {
    func withLock<Result>(_ block: () throws -> Result) rethrows -> Result {
        lock()
        defer { unlock() }
        return try block()
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
}

private class LockImplementation: Lockable {
    init() {}

    func lock() {}
    func unlock() {}
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
}

private final class PosixMutex: LockImplementation {
    private var mutex = pthread_mutex_t()

    override init() {
        let result = pthread_mutex_init(&mutex, nil)
        precondition(result == 0)
    }

    deinit {
        let result = pthread_mutex_destroy(&mutex)
        precondition(result == 0)
    }

    override func lock() {
        let result = pthread_mutex_lock(&mutex)
        precondition(result == 0)
    }

    override func unlock() {
        let result = pthread_mutex_unlock(&mutex)
        precondition(result == 0)
    }
}
