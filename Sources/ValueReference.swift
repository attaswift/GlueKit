//
//  ValueReference.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-11-02.
//  Copyright © 2015–2017 Károly Lőrentey.
//

extension ObservableValueType where Value: ObservableValueType {
    public func unpacked() -> AnyObservableValue<Value.Value> {
        return UnpackedObservableValueReference(self).anyObservableValue
    }
}

private final class UnpackedObservableValueReference<Reference: ObservableValueType>: _BaseObservableValue<Reference.Value.Value>
where Reference.Value: ObservableValueType {
    typealias Target = Reference.Value
    typealias Value = Target.Value
    typealias Change = ValueChange<Value>

    private struct ReferenceSink: UniqueOwnedSink {
        typealias Owner = UnpackedObservableValueReference

        unowned(unsafe) let owner: Owner

        func receive(_ update: ValueUpdate<Reference.Value>) {
            owner.applyReferenceUpdate(update)
        }
    }

    private struct TargetSink: UniqueOwnedSink {
        typealias Owner = UnpackedObservableValueReference

        unowned(unsafe) let owner: Owner

        func receive(_ update: ValueUpdate<Reference.Value.Value>) {
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
                sendChange(ValueChange(from: change.old.value, to: change.new.value))
            }
        case .endTransaction:
            endTransaction()
        }
    }

    func applyTargetUpdate(_ update: ValueUpdate<Value>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            sendChange(change)
        case .endTransaction:
            endTransaction()
        }
    }

    override var value: Value { return _reference.value.value }
}
