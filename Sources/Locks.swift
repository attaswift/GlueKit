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
    func withLock<Result>(_ block: @noescape (Void) -> Result) -> Result
}

extension Lockable {
    func withLock<Result>(_ block: @noescape (Void) -> Result) -> Result {
        lock()
        defer { unlock() }
        return block()
    }
}

internal class Mutex: Lockable {
    private var mutex = pthread_mutex_t()

    init() {
        let result = pthread_mutex_init(&mutex, nil)
        if result != 0 {
            preconditionFailure("pthread_mutex_init returned \(result)")
        }
    }

    func destroy() {
        let result = pthread_mutex_destroy(&mutex)
        if result != 0 {
            preconditionFailure("pthread_mutex_destroy returned \(result)")
        }
    }

    func lock() {
        let result = pthread_mutex_lock(&mutex)
        if result != 0 {
            preconditionFailure("pthread_mutex_lock returned \(result)")
        }
    }

    func unlock() {
        let result = pthread_mutex_unlock(&mutex)
        if result != 0 {
            preconditionFailure("pthread_mutex_unlock returned \(result)")
        }
    }

    func tryLock() -> Bool {
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

extension Lock: Lockable {
    internal convenience init(name: String) {
        self.init()
        self.name = name
    }
}

extension RecursiveLock: Lockable {
    internal convenience init(name: String) {
        self.init()
        self.name = name
    }
}
