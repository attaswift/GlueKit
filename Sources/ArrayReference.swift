//
//  ArrayReference.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-17.
//  Copyright © 2015–2017 Károly Lőrentey.
//

extension ObservableValueType where Value: ObservableArrayType{
    public func unpacked() -> AnyObservableArray<Value.Element> {
        return UnpackedObservableArrayReference(self).anyObservableArray
    }
}

/// A mutable reference to an `AnyObservableArray` that's also an observable array.
/// You can switch to another target array without having to re-register subscribers.
private final class UnpackedObservableArrayReference<Reference: ObservableValueType>: _BaseObservableArray<Reference.Value.Element>
where Reference.Value: ObservableArrayType {
    typealias Target = Reference.Value
    typealias Element = Target.Element
    typealias Change = ArrayChange<Element>

    private struct ReferenceSink: UniqueOwnedSink {
        typealias Owner = UnpackedObservableArrayReference
        
        unowned(unsafe) let owner: Owner
        
        func receive(_ update: ValueUpdate<Reference.Value>) {
            owner.applyReferenceUpdate(update)
        }
    }
    
    private struct TargetSink: UniqueOwnedSink {
        typealias Owner = UnpackedObservableArrayReference
        
        unowned(unsafe) let owner: Owner
        
        func receive(_ update: ArrayUpdate<Reference.Value.Element>) {
            owner.applyTargetUpdate(update)
        }
    }
    
    private var _reference: Reference
    private var _target: Reference.Value? = nil // Retained to make sure we keep it alive

    init(_ reference: Reference) {
        _reference = reference
        super.init()
    }

    override func activate() {
        _reference.updates.add(ReferenceSink(owner: self))
        let target = _reference.value
        _target = target
        target.updates.add(TargetSink(owner: self))
    }

    override func deactivate() {
        _target!.updates.remove(TargetSink(owner: self))
        _reference.updates.remove(ReferenceSink(owner: self))
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
                sendChange(ArrayChange(from: change.old.value, to: change.new.value))
            }
        case .endTransaction:
            endTransaction()
        }
    }

    func applyTargetUpdate(_ update: ArrayUpdate<Element>) {
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
    override subscript(_ index: Int) -> Element { return _reference.value[index] }
    override subscript(_ range: Range<Int>) -> ArraySlice<Element> { return _reference.value[range] }
    override var value: [Element] { return _reference.value.value }
    override var count: Int { return _reference.value.count }
}
