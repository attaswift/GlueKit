//
//  SetReference.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-17.
//  Copyright © 2015–2017 Károly Lőrentey.
//

extension ObservableValueType where Value: ObservableSetType {
    public func unpacked() -> AnyObservableSet<Value.Element> {
        return UnpackedObservableSetReference(self).anyObservableSet
    }
}

/// A mutable reference to an `AnyObservableSet` that's also an observable set.
/// You can switch to another target set without having to re-register subscribers.
private final class UnpackedObservableSetReference<Reference: ObservableValueType>: _BaseObservableSet<Reference.Value.Element>
where Reference.Value: ObservableSetType {
    typealias Target = Reference.Value
    typealias Element = Target.Element
    typealias Change = SetChange<Element>

    private struct ReferenceSink: UniqueOwnedSink {
        typealias Owner = UnpackedObservableSetReference
        
        unowned(unsafe) let owner: Owner
        
        func receive(_ update: ValueUpdate<Reference.Value>) {
            owner.applyReferenceUpdate(update)
        }
    }
    
    private struct TargetSink: UniqueOwnedSink {
        typealias Owner = UnpackedObservableSetReference
        
        unowned(unsafe) let owner: Owner
        
        func receive(_ update: SetUpdate<Reference.Value.Element>) {
            owner.applyTargetUpdate(update)
        }
    }
    
    private var _reference: Reference
    private var _target: Reference.Value? = nil // Retained to make sure we keep it alive

    init(_ reference: Reference)  {
        _reference = reference
        super.init()
    }

    override func activate() {
        _reference.add(ReferenceSink(owner: self))
        let target = _reference.value
        _target = target
        target.add(TargetSink(owner: self))
    }

    override func deactivate() {
        _target!.remove(TargetSink(owner: self))
        _reference.remove(ReferenceSink(owner: self))
    }

    func applyReferenceUpdate(_ update: ValueUpdate<Target>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            if isConnected {
                _target!.remove(TargetSink(owner: self))
                _target = change.new
                _target!.add(TargetSink(owner: self))
                sendChange(SetChange(from: change.old.value, to: change.new.value))
            }
        case .endTransaction:
            endTransaction()
        }
    }

    func applyTargetUpdate(_ update: SetUpdate<Element>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            sendChange(change)
        case .endTransaction:
            endTransaction()
        }
    }

    override var isBuffered: Bool { return false }
    override var count: Int { return _reference.value.count }
    override var value: Set<Element> { return _reference.value.value }
    override func contains(_ member: Element) -> Bool { return _reference.value.contains(member) }
    override func isSubset(of other: Set<Element>) -> Bool { return _reference.value.isSubset(of: other) }
    override func isSuperset(of other: Set<Element>) -> Bool { return _reference.value.isSuperset(of: other) }
}
