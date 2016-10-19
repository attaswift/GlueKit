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

private class KVOUpdatable: NSObject, UpdatableValueType, SignalDelegate {
    typealias Value = Any?
    typealias Change = ValueChange<Any?>

    private let object: NSObject
    private let keyPath: String
    private var state = TransactionState<Change>()
    private var context: UInt8 = 0

    init(object: NSObject, keyPath: String) {
        self.object = object
        self.keyPath = keyPath
        super.init()
    }

    func get() -> Any? {
        return object.value(forKeyPath: keyPath)
    }

    func update(_ body: (Any?) -> Any?) {
        object.setValue(body(get()), forKeyPath: keyPath)
    }

    var updates: ValueUpdateSource<Any?> { return state.source(retainingDelegate: self) }

    func start(_ signal: Signal<ValueUpdate<Any?>>) {
        object.addObserver(self, forKeyPath: keyPath, options: [.old, .new, .prior], context: &context)
    }

    func stop(_ signal: Signal<ValueUpdate<Any?>>) {
        object.removeObserver(self, forKeyPath: keyPath, context: &context)
    }

    @objc override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &self.context {
            if (change![.notificationIsPriorKey] as? NSNumber)?.boolValue == true {
                state.begin()
            }
            else {
                precondition(state.isChanging)
                let oldValue = change![.oldKey]
                let newValue = change![.newKey]
                let old: Any? = (oldValue is NSNull ? nil : oldValue)
                let new: Any? = (newValue is NSNull ? nil : newValue)
                state.send(Change(from: old, to: new))
                state.end()
            }
        }
        else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
}
