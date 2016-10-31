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
    public func observable(forKeyPath keyPath: String) -> AnyObservableValue<Any?> {
        return KVOUpdatable(object: self, keyPath: keyPath).anyObservableValue
    }

    public func observable<T>(forKeyPath keyPath: String, as type: T.Type = T.self) -> AnyObservableValue<T> {
        return KVOUpdatable(object: self, keyPath: keyPath).map { $0 as! T }
    }

    public func observable<T>(forKeyPath keyPath: String, as type: T?.Type = Optional<T>.self) -> AnyObservableValue<T?> {
        return KVOUpdatable(object: self, keyPath: keyPath).map { $0 as? T }
    }

    /// Returns an updatable for the value of a KVO-compatible key path.
    /// The object is retained by the returned source.
    public func updatable(forKeyPath keyPath: String) -> AnyUpdatableValue<Any?> {
        return KVOUpdatable(object: self, keyPath: keyPath).anyUpdatableValue
    }

    public func updatable<T>(forKeyPath keyPath: String, as type: T.Type = T.self) -> AnyUpdatableValue<T> {
        return KVOUpdatable(object: self, keyPath: keyPath).map({ $0 as! T }, inverse: { $0 as Any })
    }
    public func updatable<T>(forKeyPath keyPath: String, as type: T?.Type = Optional<T>.self) -> AnyUpdatableValue<T?> {
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

    var value: Any? {
        get {
            return object.value(forKeyPath: keyPath)
        }
        set {
            object.setValue(newValue, forKeyPath: keyPath)
        }
    }

    func apply(_ update: Update<ValueChange<Any?>>) {
        switch update {
        case .beginTransaction:
            state.begin()
        case .change(let change):
            object.setValue(change.new, forKeyPath: keyPath)
        case .endTransaction:
            state.end()
        }
    }

    func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        state.add(sink, with: self)
    }

    @discardableResult
    func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        return state.remove(sink)
    }

    func activate() {
        object.addObserver(self, forKeyPath: keyPath, options: [.old, .new, .prior], context: &context)
    }

    func deactivate() {
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
