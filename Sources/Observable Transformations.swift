//
//  Observable Transformations.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-07.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

// MARK: Buffered

internal class BufferedObservable<Base: ObservableValueType>: ObservableValueType {
    typealias Value = Base.Value

    private var base: Base

    var value: Base.Value
    var connection: Connection? = nil

    init(_ base: Base) {
        self.base = base
        self.value = base.value

        connection = base.futureValues.connect { [weak self] value in
            self?.value = value
        }
    }

    var changes: Source<ValueChange<Base.Value>> {
        return base.changes
    }
    var futureValues: Source<Base.Value> {
        return base.futureValues
    }
}

extension ObservableValueType {
    public func buffered() -> Observable<Value> {
        return BufferedObservable(self).observable
    }
}

// MARK: Map

public extension ObservableValueType {
    /// Returns an observable that calculates `transform` on all current and future values of this observable.
    public func map<Output>(_ transform: @escaping (Value) -> Output) -> Observable<Output> {
        return Observable(getter: { transform(self.value) },
                          changes: { self.changes.map { $0.map(transform) } })
    }
}

extension UpdatableType {
    public func map<Output>(_ transform: @escaping (Value) -> Output, inverse: @escaping (Output) -> Value) -> Updatable<Output> {
        return Updatable(getter: { transform(self.value) },
                         setter: { self.value = inverse($0) },
                         changes: { self.changes.map { $0.map(transform) } })
    }
}

// MARK: Distinct

public extension ObservableValueType {
    public func distinct(_ equalityTest: @escaping (Value, Value) -> Bool) -> Observable<Value> {
        return Observable(getter: { self.value },
                          changes: { self.changes.filter { !equalityTest($0.old, $0.new) } })
    }
}

public extension ObservableValueType where Value: Equatable {
    public func distinct() -> Observable<Value> {
        return distinct(==)
    }
}

public extension UpdatableType {
    public func distinct(_ equalityTest: @escaping (Value, Value) -> Bool) -> Updatable<Value> {
        return Updatable(getter: { self.value },
                         setter: { self.value = $0 },
                         changes: { self.changes.filter { !equalityTest($0.old, $0.new) } })
    }
}

public extension UpdatableType where Value: Equatable {
    public func distinct() -> Updatable<Value> {
        return distinct(==)
    }
}

// MARK: Combine

/// An Observable that is calculated from two other observables.
public final class BinaryCompositeObservable<Input1: ObservableValueType, Input2: ObservableValueType, Value>: ObservableValueType, SignalDelegate {
    private let first: Input1
    private let second: Input2
    private let combinator: (Input1.Value, Input2.Value) -> Value
    private var signal = OwningSignal<ValueChange<Value>>()

    public init(first: Input1, second: Input2, combinator: @escaping (Input1.Value, Input2.Value) -> Value) {
        self.first = first
        self.second = second
        self.combinator = combinator
    }

    deinit {
        assert(_connections == nil)
    }

    public var value: Value {
        if let value = _value { return value }
        return combinator(first.value, second.value)
    }
    public var changes: Source<ValueChange<Value>> { return signal.with(self).source }

    private var _firstValue: Input1.Value? = nil
    private var _secondValue: Input2.Value? = nil
    private var _value: Value? = nil
    private var _connections: (Connection, Connection)? = nil

    internal func start(_ signal: Signal<ValueChange<Value>>) {
        assert(_connections == nil)
        let v1 = first.value
        let v2 = second.value
        _firstValue = v1
        _secondValue = v2
        _value = combinator(v1, v2)

        let c1 = first.changes.connect { [unowned self] change in
            let old = self._value!
            let new = self.combinator(change.new, self._secondValue!)
            self._firstValue = change.new
            self._value = new
            self.signal.send(ValueChange(from: old, to: new))
        }
        let c2 = second.changes.connect { [unowned self] change in
            let old = self._value!
            let new = self.combinator(self._firstValue!, change.new)
            self._secondValue = change.new
            self._value = new
            self.signal.send(ValueChange(from: old, to: new))
        }
        _connections = (c1, c2)
    }

    internal func stop(_ signal: Signal<ValueChange<Value>>) {
        _connections!.0.disconnect()
        _connections!.1.disconnect()
        _value = nil
        _firstValue = nil
        _secondValue = nil
        _connections = nil
    }
}

public extension ObservableValueType {
    public func combine<Other: ObservableValueType>(_ other: Other) -> Observable<(Value, Other.Value)> {
        return BinaryCompositeObservable(first: self, second: other, combinator: { ($0, $1) }).observable
    }

    public func combine<Other: ObservableValueType, Output>(_ other: Other, via combinator: @escaping (Value, Other.Value) -> Output) -> Observable<Output> {
        return BinaryCompositeObservable(first: self, second: other, combinator: combinator).observable
    }
}

public func combine<O1: ObservableValueType, O2: ObservableValueType>(_ o1: O1, _ o2: O2) -> Observable<(O1.Value, O2.Value)> {
    return o1.combine(o2)
}

public func combine<O1: ObservableValueType, O2: ObservableValueType, O3: ObservableValueType>(_ o1: O1, _ o2: O2, _ o3: O3) -> Observable<(O1.Value, O2.Value, O3.Value)> {
    return o1.combine(o2).combine(o3, via: { a, b in (a.0, a.1, b) })
}

public func combine<O1: ObservableValueType, O2: ObservableValueType, O3: ObservableValueType, O4: ObservableValueType>(_ o1: O1, _ o2: O2, _ o3: O3, _ o4: O4) -> Observable<(O1.Value, O2.Value, O3.Value, O4.Value)> {

    return combine(o1, o2, o3).combine(o4, via: { a, b in (a.0, a.1, a.2, b) })
}

public func combine<O1: ObservableValueType, O2: ObservableValueType, O3: ObservableValueType, O4: ObservableValueType, O5: ObservableValueType>(_ o1: O1, _ o2: O2, _ o3: O3, _ o4: O4, _ o5: O5) -> Observable<(O1.Value, O2.Value, O3.Value, O4.Value, O5.Value)> {

    return combine(o1, o2, o3, o4).combine(o5, via: { a, b in (a.0, a.1, a.2, a.3, b) })
}

public func combine<O1: ObservableValueType, O2: ObservableValueType, O3: ObservableValueType, O4: ObservableValueType, O5: ObservableValueType, O6: ObservableValueType>(_ o1: O1, _ o2: O2, _ o3: O3, _ o4: O4, _ o5: O5, _ o6: O6) -> Observable<(O1.Value, O2.Value, O3.Value, O4.Value, O5.Value, O6.Value)> {

    return combine(o1, o2, o3, o4, o5).combine(o6, via: { a, b in (a.0, a.1, a.2, a.3, a.4, b) })
}


/// An Updatable that is a composite of two other updatables.
internal final class CompositeUpdatable<A: UpdatableType, B: UpdatableType>: UpdatableType, SignalDelegate {
    typealias Value = (A.Value, B.Value)
    private let first: A
    private let second: B
    private var signal = OwningSignal<ValueChange<Value>>()

    private var firstValue: A.Value? = nil
    private var secondValue: B.Value? = nil
    private var connections: (Connection, Connection)? = nil

    init(first: A, second: B) {
        self.first = first
        self.second = second
    }

    final var changes: Source<ValueChange<Value>> { return signal.with(self).source }

    final var value: Value {
        get {
            if let v1 = firstValue, let v2 = secondValue { return (v1, v2) }
            return (first.value, second.value)
        }
        set {
            // Updating a composite updatable is tricky, because updating the components will trigger a synchronous update,
            // which can lead to us broadcasting intermediate states, which can result in infinite feedback loops.
            // To prevent this, we update our idea of most recent values before setting our component updatables.

            firstValue = newValue.0
            secondValue = newValue.1

            first.value = newValue.0
            second.value = newValue.1
        }
    }

    final func start(_ signal: Signal<ValueChange<Value>>) {
        precondition(connections == nil)
        firstValue = first.value
        secondValue = second.value
        let c1 = first.changes.connect { [unowned self] change in
            let old = (change.old, self.secondValue!)
            let new = (change.new, self.secondValue!)
            self.firstValue = change.new
            signal.send(ValueChange(from: old, to: new))
        }
        let c2 = second.changes.connect { [unowned self] change in
            let old = (self.firstValue!, change.old)
            let new = (self.firstValue!, change.new)
            self.secondValue = change.new
            signal.send(ValueChange(from: old, to: new))
        }
        connections = (c1, c2)
    }

    final func stop(_ signal: Signal<ValueChange<Value>>) {
        connections!.0.disconnect()
        connections!.1.disconnect()
        firstValue = nil
        secondValue = nil
        connections = nil
    }
}

public extension UpdatableType {
    public func combine<Other: UpdatableType>(_ other: Other) -> Updatable<(Value, Other.Value)> {
        return CompositeUpdatable(first: self, second: other).updatable
    }
}

public func combine<O1: UpdatableType, O2: UpdatableType>(_ o1: O1, _ o2: O2) -> Updatable<(O1.Value, O2.Value)> {
    return o1.combine(o2)
}

public func combine<O1: UpdatableType, O2: UpdatableType, O3: UpdatableType>(_ o1: O1, _ o2: O2, _ o3: O3) -> Updatable<(O1.Value, O2.Value, O3.Value)> {
    return o1.combine(o2).combine(o3)
        .map({ a, b in (a.0, a.1, b) },
             inverse: { v in ((v.0, v.1), v.2) })
}

public func combine<O1: UpdatableType, O2: UpdatableType, O3: UpdatableType, O4: UpdatableType>(_ o1: O1, _ o2: O2, _ o3: O3, _ o4: O4) -> Updatable<(O1.Value, O2.Value, O3.Value, O4.Value)> {
    return o1.combine(o2).combine(o3).combine(o4)
        .map({ a, b in (a.0.0, a.0.1, a.1, b) },
             inverse: { v in (((v.0, v.1), v.2), v.3) })
}

public func combine<O1: UpdatableType, O2: UpdatableType, O3: UpdatableType, O4: UpdatableType, O5: UpdatableType>(_ o1: O1, _ o2: O2, _ o3: O3, _ o4: O4, _ o5: O5) -> Updatable<(O1.Value, O2.Value, O3.Value, O4.Value, O5.Value)> {
    return o1.combine(o2).combine(o3).combine(o4).combine(o5)
        .map({ a, b in (a.0.0.0, a.0.0.1, a.0.1, a.1, b) },
             inverse: { v in ((((v.0, v.1), v.2), v.3), v.4) })
}

public func combine<O1: UpdatableType, O2: UpdatableType, O3: UpdatableType, O4: UpdatableType, O5: UpdatableType, O6: UpdatableType>(_ o1: O1, _ o2: O2, _ o3: O3, _ o4: O4, _ o5: O5, _ o6: O6) -> Updatable<(O1.Value, O2.Value, O3.Value, O4.Value, O5.Value, O6.Value)> {
    return o1.combine(o2).combine(o3).combine(o4).combine(o5).combine(o6)
        .map({ a, b in (a.0.0.0.0, a.0.0.0.1, a.0.0.1, a.0.1, a.1, b) },
             inverse: { v in (((((v.0, v.1), v.2), v.3), v.4), v.5) })
}

//MARK: Operations with observables of equatable values

public func == <Value: Equatable>(a: Observable<Value>, b: Observable<Value>) -> Observable<Bool> {
    return a.combine(b, via: ==)
}

public func != <Value: Equatable>(a: Observable<Value>, b: Observable<Value>) -> Observable<Bool> {
    return a.combine(b, via: !=)
}

//MARK: Operations with observables of comparable values

public func < <Value: Comparable>(a: Observable<Value>, b: Observable<Value>) -> Observable<Bool> {
    return a.combine(b, via: <)
}

public func > <Value: Comparable>(a: Observable<Value>, b: Observable<Value>) -> Observable<Bool> {
    return a.combine(b, via: >)
}

public func <= <Value: Comparable>(a: Observable<Value>, b: Observable<Value>) -> Observable<Bool> {
    return a.combine(b, via: <=)
}

public func >= <Value: Comparable>(a: Observable<Value>, b: Observable<Value>) -> Observable<Bool> {
    return a.combine(b, via: >=)
}

public func min<Value: Comparable>(_ a: Observable<Value>, _ b: Observable<Value>) -> Observable<Value> {
    return a.combine(b, via: min)
}

public func max<Value: Comparable>(_ a: Observable<Value>, _ b: Observable<Value>) -> Observable<Value> {
    return a.combine(b, via: max)
}

//MARK: Operations with observables of boolean values

public prefix func !(v: Observable<Bool>) -> Observable<Bool> {
    return v.map { !$0 }
}

public func &&(a: Observable<Bool>, b: Observable<Bool>) -> Observable<Bool> {
    return a.combine(b, via: { a, b in a && b })
}

public func ||(a: Observable<Bool>, b: Observable<Bool>) -> Observable<Bool> {
    return a.combine(b, via: { a, b in a || b })
}

//MARK: Operations with observables of integer arithmetic values

public prefix func - <Num: SignedNumber>(v: Observable<Num>) -> Observable<Num> {
    return v.map { -$0 }
}

public func + <Num: IntegerArithmetic>(a: Observable<Num>, b: Observable<Num>) -> Observable<Num> {
    return a.combine(b, via: +)
}

public func - <Num: IntegerArithmetic>(a: Observable<Num>, b: Observable<Num>) -> Observable<Num> {
    return a.combine(b, via: -)
}

public func * <Num: IntegerArithmetic>(a: Observable<Num>, b: Observable<Num>) -> Observable<Num> {
    return a.combine(b, via: *)
}

public func / <Num: IntegerArithmetic>(a: Observable<Num>, b: Observable<Num>) -> Observable<Num> {
    return a.combine(b, via: /)
}

public func % <Num: IntegerArithmetic>(a: Observable<Num>, b: Observable<Num>) -> Observable<Num> {
    return a.combine(b, via: %)
}

//MARK: Operations with floating point values

public prefix func - <Number: FloatingPoint>(v: Observable<Number>) -> Observable<Number> {
    return v.map { -$0 }
}

public func + <Number: FloatingPoint>(a: Observable<Number>, b: Observable<Number>) -> Observable<Number> {
    return a.combine(b, via: +)
}

public func - <Number: FloatingPoint>(a: Observable<Number>, b: Observable<Number>) -> Observable<Number> {
    return a.combine(b, via: -)
}

public func * <Number: FloatingPoint>(a: Observable<Number>, b: Observable<Number>) -> Observable<Number> {
    return a.combine(b, via: *)
}

public func / <Number: FloatingPoint>(a: Observable<Number>, b: Observable<Number>) -> Observable<Number> {
    return a.combine(b, via: /)
}
