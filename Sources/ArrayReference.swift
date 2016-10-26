//
//  ArrayReference.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-17.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

extension ObservableValueType where Value: ObservableArrayType {
    public func unpacked() -> AnyObservableArray<Value.Element> {
        return UnpackedObservableArrayReference(self).anyObservableArray
    }
}

/// A mutable reference to an `AnyObservableArray` that's also an observable array.
/// You can switch to another target array without having to re-register subscribers.
private final class UnpackedObservableArrayReference<ArrayReference: ObservableValueType>: _BaseObservableArray<ArrayReference.Value.Element> where ArrayReference.Value: ObservableArrayType {
    typealias Target = ArrayReference.Value
    typealias Element = Target.Element
    typealias Change = ArrayChange<Element>

    private var _reference: ArrayReference

    init(_ reference: ArrayReference) {
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
        return MethodSink(owner: self, identifier: 0, method: UnpackedObservableArrayReference.applyReferenceUpdate).anySink
    }

    private var targetSink: AnySink<ArrayUpdate<Element>> {
        return MethodSink(owner: self, identifier: 0, method: UnpackedObservableArrayReference.applyTargetUpdate).anySink
    }

    private func applyReferenceUpdate(_ update: ValueUpdate<Target>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            if isConnected {
                change.old.updates.remove(targetSink)
                change.new.updates.add(targetSink)
                sendChange(ArrayChange(from: change.old.value, to: change.new.value))
            }
        case .endTransaction:
            endTransaction()
        }
    }

    private func applyTargetUpdate(_ update: ArrayUpdate<Element>) {
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
