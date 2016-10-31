//
//  SetFolding.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-09.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

extension ObservableSetType where Change == SetChange<Element> {
    /// Returns an observable whose value is always equal to `self.value.reduce(initial, add)`.
    ///
    /// - Parameter initial: The accumulation starts with this initial value.
    /// - Parameter add: A closure that adds an element of the set into an accumulated value.
    /// - Parameter remove: A closure that cancels the effect of an earlier `add`.
    /// - Returns: An observable value for the reduction of this set.
    ///
    /// - Note: Elements are added and removed in no particular order.
    ///    (I.e., the underlying binary operation over `Result` must form an abelian group.)
    ///
    /// - SeeAlso: `sum()` which returns a reduction using addition.
    public func reduce<Result>(_ initial: Result, add: @escaping (Result, Element) -> Result, remove: @escaping (Result, Element) -> Result) -> AnyObservableValue<Result> {
        return SetFoldingByTwoWayFunction<Self, Result>(parent: self, initial: initial, add: add, remove: remove).anyObservableValue
    }
}

extension ObservableSetType where Element: IntegerArithmetic & ExpressibleByIntegerLiteral, Change == SetChange<Element> {
    /// Return the (observable) sum of the elements contained in this set.
    public func sum() -> AnyObservableValue<Element> {
        return reduce(0, add: +, remove: -)
    }
}

private struct FoldingSink<Parent: ObservableSetType, Value>: UniqueOwnedSink
where Parent.Change == SetChange<Parent.Element> {
    typealias Owner = SetFoldingByTwoWayFunction<Parent, Value>

    unowned(unsafe) let owner: Owner

    func receive(_ update: SetUpdate<Parent.Element>) {
        owner.applyUpdate(update)
    }
}

private class SetFoldingByTwoWayFunction<Parent: ObservableSetType, Value>: _BaseObservableValue<Value>
where Parent.Change == SetChange<Parent.Element> {
    let parent: Parent
    let add: (Value, Parent.Element) -> Value
    let remove: (Value, Parent.Element) -> Value

    private var _value: Value

    init(parent: Parent, initial: Value, add: @escaping (Value, Parent.Element) -> Value, remove: @escaping (Value, Parent.Element) -> Value) {
        self.parent = parent
        self.add = add
        self.remove = remove

        self._value = parent.value.reduce(initial, add)

        super.init()

        parent.add(FoldingSink(owner: self))
    }

    deinit {
        parent.remove(FoldingSink(owner: self))
    }

    override var value: Value {
        return _value
    }

    func applyUpdate(_ update: SetUpdate<Parent.Element>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            let old = _value
            for old in change.removed { _value = remove(_value, old) }
            for new in change.inserted { _value = add(_value, new) }
            sendChange(ValueChange(from: old, to: _value))
        case .endTransaction:
            endTransaction()
        }
    }
}
