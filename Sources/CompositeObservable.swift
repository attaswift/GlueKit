//
//  CompositeObservable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-09.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableValueType {
    public func combine<Other: ObservableValueType>(_ other: Other) -> Observable<(Value, Other.Value)> {
        return CompositeObservable(first: self, second: other, combinator: { ($0, $1) }).observable
    }

    public func combine<Other: ObservableValueType, Output>(_ other: Other, via combinator: @escaping (Value, Other.Value) -> Output) -> Observable<Output> {
        return CompositeObservable(first: self, second: other, combinator: combinator).observable
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


/// An Observable that is calculated from two other observables.
private final class CompositeObservable<Input1: ObservableValueType, Input2: ObservableValueType, Value>: ObservableValueType, SignalDelegate {
    private let first: Input1
    private let second: Input2
    private let combinator: (Input1.Value, Input2.Value) -> Value
    private var signal = OwningSignal<SimpleChange<Value>>()

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
    public var changes: Source<SimpleChange<Value>> { return signal.with(self).source }

    private var _firstValue: Input1.Value? = nil
    private var _secondValue: Input2.Value? = nil
    private var _value: Value? = nil
    private var _connections: (Connection, Connection)? = nil

    internal func start(_ signal: Signal<SimpleChange<Value>>) {
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
            self.signal.send(SimpleChange(from: old, to: new))
        }
        let c2 = second.changes.connect { [unowned self] change in
            let old = self._value!
            let new = self.combinator(self._firstValue!, change.new)
            self._secondValue = change.new
            self._value = new
            self.signal.send(SimpleChange(from: old, to: new))
        }
        _connections = (c1, c2)
    }

    internal func stop(_ signal: Signal<SimpleChange<Value>>) {
        _connections!.0.disconnect()
        _connections!.1.disconnect()
        _value = nil
        _firstValue = nil
        _secondValue = nil
        _connections = nil
    }
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
