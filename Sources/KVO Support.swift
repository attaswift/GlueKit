//
//  KVO Support.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-11-30.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

public extension NSObject {
    /// Returns an observable for the value of a KVO-compatible key path.
    /// Note that the object is retained by the returned source.
    public func observable(forKeyPath keyPath: String) -> Observable<Any?> {
        return KVOUpdatable(object: self, keyPath: keyPath).observable
    }

    public func observable<T>(forKeyPath keyPath: String, as type: T.Type = T.self) -> Observable<T> {
        return KVOUpdatable(object: self, keyPath: keyPath).map { $0 as! T }
    }

    public func observable<T>(forKeyPath keyPath: String, as type: T?.Type = Optional<T>.self) -> Observable<T?> {
        return KVOUpdatable(object: self, keyPath: keyPath).map { $0 as? T }
    }

    /// Returns an updatable for the value of a KVO-compatible key path.
    /// The object is retained by the returned source.
    public func updatable(forKeyPath keyPath: String) -> Updatable<Any?> {
        return KVOUpdatable(object: self, keyPath: keyPath).updatable
    }

    public func updatable<T>(forKeyPath keyPath: String, as type: T.Type = T.self) -> Updatable<T> {
        return KVOUpdatable(object: self, keyPath: keyPath).map({ $0 as! T }, inverse: { $0 as Any })
    }
    public func updatable<T>(forKeyPath keyPath: String, as type: T?.Type = Optional<T>.self) -> Updatable<T?> {
        return KVOUpdatable(object: self, keyPath: keyPath).map({ $0 as! T? }, inverse: { $0 as Any? })
    }

}

private struct KVOUpdatable: UpdatableValueType {
    typealias Value = Any?
    typealias Change = ValueChange<Any?>

    private let object: NSObject
    private let keyPath: String

    private var observer: KVOObserver {
        return .observer(for: object)
    }

    init(object: NSObject, keyPath: String) {
        self.object = object
        self.keyPath = keyPath
    }

    var value: Any? {
        get { return object.value(forKeyPath: keyPath) }
        nonmutating set { object.setValue(newValue, forKeyPath: keyPath) }
    }

    var changes: Source<Change> { return observer._source(forKeyPath: keyPath) }
}

// A single object that observes all key paths currently registered as Sources on a target object.
// Each Source associated with a key path holds a strong reference to this object.
@objc private class KVOObserver: NSObject {
    typealias Change = ValueChange<Any?>

    static private var associatedObjectKey: Int8 = 0

    var object: NSObject

    let lock = Lock()
    var signals: [String: UnownedReference<Signal<Change>>] = [:]
    var observerContext: Int8 = 0

    static func observer(for object: NSObject) -> KVOObserver {
        if let observer = objc_getAssociatedObject(object, &associatedObjectKey) as? KVOObserver {
            return observer
        }
        else {
            let observer = KVOObserver(object: object)
            objc_setAssociatedObject(object, &associatedObjectKey, observer, .OBJC_ASSOCIATION_ASSIGN)
            return observer
        }
    }

    init(object: NSObject) {
        self.object = object
        super.init()
    }

    deinit {
        objc_setAssociatedObject(object, &KVOObserver.associatedObjectKey, nil, .OBJC_ASSOCIATION_ASSIGN)
    }

    func _source(forKeyPath keyPath: String) -> Source<Change> {
        return lock.withLock {
            if let signal = signals[keyPath] {
                return signal.value.source
            }
            let signal = Signal<Change>(
                start: { signal in self.startObservingKeyPath(keyPath, signal: signal) },
                stop: { signal in self.stopObservingKeyPath(keyPath) })
            // Note that signal now holds strong references to this KVOObserver
            signals[keyPath] = UnownedReference(signal)
            return signal.source
        }
    }

    private func startObservingKeyPath(_ keyPath: String, signal: Signal<Change>) {
        lock.withLock {
            self.signals[keyPath] = UnownedReference(signal)
            self.object.addObserver(self, forKeyPath: keyPath, options: [.old, .new], context: &self.observerContext)
        }
    }

    private func stopObservingKeyPath(_ keyPath: String) {
        lock.withLock {
            self.signals[keyPath] = nil
            self.object.removeObserver(self, forKeyPath: keyPath, context: &self.observerContext)
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &observerContext {
            if let keyPath = keyPath, let change = change {
                let oldValue = change[.oldKey]
                let newValue = change[.newKey]
                if let signal = lock.withLock({ self.signals[keyPath]?.value }) {
                    let old: Any? = (oldValue is NSNull ? nil : oldValue)
                    let new: Any? = (newValue is NSNull ? nil : newValue)
                    signal.send(.init(from: old, to: new))
                }
            }
            else {
                fatalError("Unexpected KVO callback with key path '\(keyPath)'")
            }
        }
        else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
}

