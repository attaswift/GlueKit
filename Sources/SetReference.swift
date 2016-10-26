//
//  SetReference.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-17.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

extension ObservableValueType where Value: ObservableSetType {
    public func unpacked() -> AnyObservableSet<Value.Element> {
        return UnpackedObservableSetReference(self).anyObservableSet
    }
}

/// A mutable reference to an `AnyObservableSet` that's also an observable set.
/// You can switch to another target set without having to re-register subscribers.
private final class UnpackedObservableSetReference<SetReference: ObservableValueType>: _BaseObservableSet<SetReference.Value.Element> where SetReference.Value: ObservableSetType {
    typealias Target = SetReference.Value
    typealias Element = Target.Element
    typealias Change = SetChange<Element>

    private var _reference: SetReference

    init(_ reference: SetReference)  {
        _reference = reference
        super.init()
    }

    override func activate() {
        _reference.updates.add(referenceSink)
        _reference.value.updates.add(targetSink)
    }

    override func deactivate() {
        _reference.value.updates.remove(targetSink)
        _reference.updates.remove(referenceSink)
    }

    private var referenceSink: AnySink<ValueUpdate<Target>> {
        return MethodSink(owner: self, identifier: 0, method: UnpackedObservableSetReference.applyReferenceUpdate).anySink
    }

    private var targetSink: AnySink<SetUpdate<Element>> {
        return MethodSink(owner: self, identifier: 0, method: UnpackedObservableSetReference.applyTargetUpdate).anySink
    }

    private func applyReferenceUpdate(_ update: ValueUpdate<Target>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            if isConnected {
                change.old.updates.remove(targetSink)
                change.new.updates.add(targetSink)
                sendChange(SetChange(from: change.old.value, to: change.new.value))
            }
        case .endTransaction:
            endTransaction()
        }
    }

    private func applyTargetUpdate(_ update: SetUpdate<Element>) {
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
