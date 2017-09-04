//
//  NSObject Glue.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-04-11.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import Foundation

extension NSObjectProtocol where Self: NSObject {
    public func observable<Value>(for keyPath: KeyPath<Self, Value>) -> AnyObservableValue<Value> {
        return ModernKVOObservable(self, keyPath).anyObservableValue
    }

    public func updatable<Value>(for keyPath: ReferenceWritableKeyPath<Self, Value>) -> AnyUpdatableValue<Value> {
        return ModernKVOUpdatable(self, keyPath).anyUpdatableValue
    }
}

private class ModernKVOObservation<Root: NSObject, Value>: Hashable {
    typealias Sink = AnySink<ValueUpdate<Value>>
    let sink: Sink
    var observation: NSKeyValueObservation!
    var transactionCount: Int = 0
    var pendingOld: Value? = nil
    var pendingNew: Value? = nil

    init(object: Root, keyPath: KeyPath<Root, Value>, sink: Sink) {
        self.sink = sink.anySink
        self.observation = object.observe(keyPath, options: [.prior, .old, .new], changeHandler: self.observeChange)
    }

    var hashValue: Int { return sink.hashValue }
    public static func ==(left: ModernKVOObservation, right: ModernKVOObservation) -> Bool {
        return left.sink == right.sink
    }

    func invalidate() {
        observation.invalidate()
        if transactionCount > 0 {
            sink.receive(.endTransaction)
        }
    }

    func closeTransaction() {
        precondition(transactionCount > 0)
        guard transactionCount == 1 else { transactionCount -= 1; return }
        while let new = pendingNew {
            let old = pendingOld!
            pendingOld = new
            pendingNew = nil
            sink.receive(.change(.init(from: old, to: new)))
            precondition(transactionCount > 0)
        }
        transactionCount -= 1
        if transactionCount == 0 {
            pendingOld = nil
            sink.receive(.endTransaction)
        }
    }

    func observeChange(object: Root, change: NSKeyValueObservedChange<Value>) {
        if change.isPrior {
            transactionCount += 1
            if transactionCount == 1 {
                precondition(pendingOld == nil)
                // Weird round trip through Any is because change.oldValue/.newValue is nil if value is a nil optional.
                pendingOld = ((change.oldValue as Any) as! Value)
                sink.receive(.beginTransaction)
            }
        }
        else {
            precondition(transactionCount > 0)
            // Weird round trip through Any is because change.oldValue/.newValue is nil if value is a nil optional.
            pendingNew = ((change.newValue as Any) as! Value)
            closeTransaction()
        }
    }
}


private class ModernKVOObservable<Root: NSObject, Value>: _AbstractObservableValue<Value> {
    typealias Sink = AnySink<ValueUpdate<Value>>

    let object: Root
    let keyPath: KeyPath<Root, Value>

    var sinks: [Sink: ModernKVOObservation<Root, Value>] = [:]

    init(_ object: Root, _ keyPath: KeyPath<Root, Value>) {
        self.object = object
        self.keyPath = keyPath
    }

    override var value: Value {
        return object[keyPath: keyPath]
    }

    override func add<Sink>(_ sink: Sink) where Sink: SinkType, Sink.Value == Update<Change> {
        let r = sinks.updateValue(ModernKVOObservation(object: object, keyPath: keyPath, sink: sink.anySink),
                                  forKey: sink.anySink)
        precondition(r == nil)
    }

    override func remove<Sink>(_ sink: Sink) -> Sink where Sink: SinkType, Sink.Value == Update<Change> {
        let (result, observation) = sinks.remove(at: sinks.index(forKey: sink.anySink)!)
        observation.invalidate()
        return result.opened()!
    }
}

private class ModernKVOUpdatable<Root: NSObject, Value>: _AbstractUpdatableValue<Value> {
    typealias Sink = AnySink<ValueUpdate<Value>>

    let object: Root
    let keyPath: ReferenceWritableKeyPath<Root, Value>

    var sinks: [Sink: ModernKVOObservation<Root, Value>] = [:]

    init(_ object: Root, _ keyPath: ReferenceWritableKeyPath<Root, Value>) {
        self.object = object
        self.keyPath = keyPath
    }

    override var value: Value {
        get {
            return object[keyPath: keyPath]
        }
        set {
            object[keyPath: keyPath] = newValue
        }
    }

    override func apply(_ update: Update<ValueChange<Value>>) {
        switch update {
        case .beginTransaction:
            object.willChangeValue(for: keyPath)
        case .change(let change):
            object[keyPath: keyPath] = change.new
        case .endTransaction:
            object.didChangeValue(for: keyPath)
        }
    }

    override func add<Sink>(_ sink: Sink) where Sink: SinkType, Sink.Value == Update<Change> {
        let r = sinks.updateValue(ModernKVOObservation(object: object, keyPath: keyPath, sink: sink.anySink),
                                  forKey: sink.anySink)
        precondition(r == nil)
    }

    override func remove<Sink>(_ sink: Sink) -> Sink where Sink: SinkType, Sink.Value == Update<Change> {
        let (result, observation) = sinks.remove(at: sinks.index(forKey: sink.anySink)!)
        observation.invalidate()
        return result.opened()!
    }
}

//

private var associatedObjectKeyForGlue: UInt8 = 0

extension NSObject {
    public func _glue<Glue: GlueForNSObject>() -> Glue {
        if let glue = objc_getAssociatedObject(self, &associatedObjectKeyForGlue) {
            return glue as! Glue
        }
        let glue = Glue(owner: self)
        objc_setAssociatedObject(self, &associatedObjectKeyForGlue, glue, .OBJC_ASSOCIATION_RETAIN)
        return glue
    }
}

extension NSObject {
    @objc open dynamic var glue: GlueForNSObject {
        return _glue()
    }
}

open class GlueForNSObject: NSObject {
    public unowned let owner: NSObject

    public private(set) lazy var connector = Connector()
    fileprivate var keyValueSources: [String: KVOSource] = [:]

    public required init(owner: NSObject) {
        self.owner = owner
    }
}

extension GlueForNSObject {
    // Key-Value Observing

    /// Returns an observable for the value of a KVO-compatible key path.
    /// Note that the object is retained by the returned source.
    public func observable(forKeyPath keyPath: String) -> KVOObservable {
        return KVOObservable(object: owner, keyPath: keyPath)
    }

    public func observable<T>(forKeyPath keyPath: String, as type: T.Type = T.self) -> AnyObservableValue<T> {
        return KVOObservable(object: owner, keyPath: keyPath).forceCasted()
    }

    public func observable<T>(forKeyPath keyPath: String, as type: T?.Type = Optional<T>.self) -> AnyObservableValue<T?> {
        return KVOObservable(object: owner, keyPath: keyPath).casted()
    }

    public func observable<T>(forKeyPath keyPath: String, defaultValue: T) -> AnyObservableValue<T> {
        return KVOObservable(object: owner, keyPath: keyPath).casted(defaultValue: defaultValue)
    }


    public func updatable(forKey key: String) -> KVOUpdatable {
        precondition(!key.contains("."), "Updatable key paths aren't supported; use GlueKit mappings instead")
        return KVOUpdatable(object: owner, key: key)
    }

    public func updatable<T>(forKey key: String, as type: T.Type = T.self) -> AnyUpdatableValue<T> {
        precondition(!key.contains("."), "Updatable key paths aren't supported; use GlueKit mappings instead")
        return KVOUpdatable(object: owner, key: key).forceCasted()
    }

    public func updatable<T>(forKey key: String, as type: T?.Type = Optional<T>.self) -> AnyUpdatableValue<T?> {
        precondition(!key.contains("."), "Updatable key paths aren't supported; use GlueKit mappings instead")
        return KVOUpdatable(object: owner, key: key).casted()
    }

    public func updatable<T>(forKey key: String, defaultValue: T) -> AnyUpdatableValue<T> {
        precondition(!key.contains("."), "Updatable key paths aren't supported; use GlueKit mappings instead")
        return KVOUpdatable(object: owner, key: key).casted(defaultValue: defaultValue)
    }
}

extension GlueForNSObject {
    fileprivate static var observingContext: UInt8 = 0

    fileprivate func add<Sink: SinkType>(_  sink: Sink, forKeyPath keyPath: String) where Sink.Value == ValueUpdate<Any?> {
        if let source = keyValueSources[keyPath] {
            source.add(sink)
        }
        else {
            let source = KVOSource(object: owner, keyPath: keyPath)
            keyValueSources[keyPath] = source
            source.add(sink)
        }
    }

    fileprivate func remove<Sink: SinkType>(_ sink: Sink, forKeyPath keyPath: String) -> Sink where Sink.Value == ValueUpdate<Any?> {
        let source = keyValueSources[keyPath]!
        let old = source.remove(sink)
        return old
    }

    @objc open override func observeValue(forKeyPath keyPath: String?,
                                            of object: Any?,
                                            change: [NSKeyValueChangeKey : Any]?,
                                            context: UnsafeMutableRawPointer?) {
        if context == &GlueForNSObject.observingContext {
            keyValueSources[keyPath!]!.process(change!)
        }
        else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
}

private final class KVOSource: TransactionalSource<ValueChange<Any?>> {
    unowned let object: NSObject
    let keyPath: String

    init(object: NSObject, keyPath: String) {
        self.object = object
        self.keyPath = keyPath
    }

    override func activate() {
        object.addObserver(object.glue, forKeyPath: keyPath, options: [.old, .new, .prior], context: &GlueForNSObject.observingContext)
    }

    override func deactivate() {
        object.removeObserver(object.glue, forKeyPath: keyPath, context: &GlueForNSObject.observingContext)
    }

    func process(_ change: [NSKeyValueChangeKey : Any]) {
        if (change[.notificationIsPriorKey] as? NSNumber)?.boolValue == true {
            beginTransaction()
        }
        else {
            precondition(isInTransaction)
            let oldValue = change[.oldKey]
            let newValue = change[.newKey]
            let old: Any? = (oldValue is NSNull ? nil : oldValue)
            let new: Any? = (newValue is NSNull ? nil : newValue)
            let change = ValueChange(from: old, to: new)
            if isInOuterMostTransaction {
                sendChange(change)
            }
            endTransaction()
        }
    }
}

public struct KVOObservable: ObservableValueType {
    public typealias Change = ValueChange<Any?>

    public let object: NSObject
    public let keyPath: String

    public var value: Any? {
        return object.value(forKeyPath: keyPath)
    }

    public func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        object.glue.add(sink, forKeyPath: keyPath)
    }

    public func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        return object.glue.remove(sink, forKeyPath: keyPath)
    }
}

public struct KVOUpdatable: UpdatableValueType {
    public typealias Change = ValueChange<Any?>

    public let object: NSObject
    public let key: String

    public var value: Any? {
        get {
            return object.value(forKey: key)
        }
        nonmutating set {
            object.setValue(newValue, forKey: key)
        }
    }

    public func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        object.glue.add(sink, forKeyPath: key)
    }

    public func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        return object.glue.remove(sink, forKeyPath: key)
    }

    public func apply(_ update: Update<ValueChange<Any?>>) {
        switch update {
        case .beginTransaction:
            object.willChangeValue(forKey: key)
        case .change(let change):
            object.setValue(change.new, forKey: key)
        case .endTransaction:
            object.didChangeValue(forKey: key)
        }
    }
}



