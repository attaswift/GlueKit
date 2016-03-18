//
//  KVO Support.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-11-30.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

public extension NSObject {
    /// Returns an observable source for a KVO-compatible key path.
    /// Note that the object is retained by the returned source.
    public func sourceForKeyPath(keyPath: String) -> Source<AnyObject> {
        return KVOObserver.observerForObject(self)._sourceForKeyPath(keyPath)
    }
}

// A single object that observes all key paths currently registered as Sources on a target object.
// Each Source associated with a key path holds a strong reference to this object.
@objc private class KVOObserver: NSObject {
    static private var associatedObjectKey: Int8 = 0

    let object: NSObject

    let mutex = Mutex()
    var signals: [String: UnownedReference<Signal<AnyObject>>] = [:]
    var observerContext: Int8 = 0

    static func observerForObject(object: NSObject) -> KVOObserver {
        if let observer = objc_getAssociatedObject(object, &associatedObjectKey) as? KVOObserver {
            return observer
        }
        else {
            let observer = KVOObserver(object: object)
            objc_setAssociatedObject(self, &associatedObjectKey, observer, .OBJC_ASSOCIATION_ASSIGN)
            return observer
        }
    }

    init(object: NSObject) {
        self.object = object
        super.init()
    }

    deinit {
        objc_setAssociatedObject(object, &KVOObserver.associatedObjectKey, nil, .OBJC_ASSOCIATION_ASSIGN)
        mutex.destroy()
    }

    func _sourceForKeyPath(keyPath: String) -> Source<AnyObject> {
        return mutex.withLock {
            if let signal = signals[keyPath] {
                return signal.value.source
            }
            let signal = Signal<AnyObject>(
                start: { signal in self.startObservingKeyPath(keyPath, signal: signal) },
                stop: { signal in self.stopObservingKeyPath(keyPath) })
            // Note that signal now holds strong references to this KVOObserver
            signals[keyPath] = UnownedReference(signal)
            return signal.source
        }
    }

    private func startObservingKeyPath(keyPath: String, signal: Signal<AnyObject>) {
        mutex.withLock {
            self.signals[keyPath] = UnownedReference(signal)
            self.object.addObserver(self, forKeyPath: keyPath, options: .New, context: &self.observerContext)
        }
    }

    private func stopObservingKeyPath(keyPath: String) {
        mutex.withLock {
            self.signals[keyPath] = nil
            self.object.removeObserver(self, forKeyPath: keyPath, context: &self.observerContext)
        }
    }

    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if context == &observerContext {
            if let keyPath = keyPath, change = change, newValue = change[NSKeyValueChangeNewKey] {
                if let signal = mutex.withLock({ self.signals[keyPath]?.value }) {
                    signal.send(newValue)
                }
            }
            else {
                fatalError("Unexpected KVO callback with key path '\(keyPath)'")
            }
        }
        else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
}

