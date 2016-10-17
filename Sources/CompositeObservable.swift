//
//  CompositeObservable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-09.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableValueType {
    public func combined<Other: ObservableValueType>(_ other: Other) -> Observable<(Value, Other.Value)> {
        return CompositeObservable(first: self, second: other, combinator: { ($0, $1) }).observable
    }

    public func combined<A: ObservableValueType, B: ObservableValueType>(_ a: A, _ b: B) -> Observable<(Value, A.Value, B.Value)> {
        return combined(a).combined(b, via: { a, b in (a.0, a.1, b) })
    }

    public func combined<A: ObservableValueType, B: ObservableValueType, C: ObservableValueType>(_ a: A, _ b: B, _ c: C) -> Observable<(Value, A.Value, B.Value, C.Value)> {
        return combined(a, b).combined(c, via: { a, b in (a.0, a.1, a.2, b) })
    }

    public func combined<A: ObservableValueType, B: ObservableValueType, C: ObservableValueType, D: ObservableValueType>(_ a: A, _ b: B, _ c: C, _ d: D) -> Observable<(Value, A.Value, B.Value, C.Value, D.Value)> {
        return combined(a, b, c).combined(d, via: { a, b in (a.0, a.1, a.2, a.3, b) })
    }

    public func combined<A: ObservableValueType, B: ObservableValueType, C: ObservableValueType, D: ObservableValueType, E: ObservableValueType>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E) -> Observable<(Value, A.Value, B.Value, C.Value, D.Value, E.Value)> {
        return combined(a, b, c, d).combined(e, via: { a, b in (a.0, a.1, a.2, a.3, a.4, b) })
    }


    public func combined<Other: ObservableValueType, Output>(_ other: Other, via combinator: @escaping (Value, Other.Value) -> Output) -> Observable<Output> {
        return CompositeObservable(first: self, second: other, combinator: combinator).observable
    }

    public func combined<A: ObservableValueType, B: ObservableValueType, Output>(_ a: A, _ b: B, via combinator: @escaping (Value, A.Value, B.Value) -> Output) -> Observable<Output> {
        return combined(a).combined(b, via: { a, b in combinator(a.0, a.1, b) })
    }

    public func combined<A: ObservableValueType, B: ObservableValueType, C: ObservableValueType, Output>(_ a: A, _ b: B, _ c: C, via combinator: @escaping (Value, A.Value, B.Value, C.Value) -> Output) -> Observable<Output> {
        return combined(a, b).combined(c, via: { a, b in combinator(a.0, a.1, a.2, b) })
    }

    public func combined<A: ObservableValueType, B: ObservableValueType, C: ObservableValueType, D: ObservableValueType, Output>(_ a: A, _ b: B, _ c: C, _ d: D, via combinator: @escaping (Value, A.Value, B.Value, C.Value, D.Value) -> Output) -> Observable<Output> {
        return combined(a, b, c).combined(d, via: { a, b in combinator(a.0, a.1, a.2, a.3, b) })
    }

    public func combined<A: ObservableValueType, B: ObservableValueType, C: ObservableValueType, D: ObservableValueType, E: ObservableValueType, Output>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, via combinator: @escaping (Value, A.Value, B.Value, C.Value, D.Value, E.Value) -> Output) -> Observable<Output> {
        return combined(a, b, c, d).combined(e, via: { a, b in combinator(a.0, a.1, a.2, a.3, a.4, b) })
    }
}

/// An Observable that is calculated from two other observables.
private final class CompositeObservable<Input1: ObservableValueType, Input2: ObservableValueType, Value>: ObservableValueType, SignalDelegate {
    typealias Change = ValueChange<Value>

    private let first: Input1
    private let second: Input2
    private let combinator: (Input1.Value, Input2.Value) -> Value

    private var _state = TransactionState<Change>()
    private var _firstValue: Input1.Value? = nil
    private var _secondValue: Input2.Value? = nil
    private var _value: Value? = nil
    private var _connections: (Connection, Connection)? = nil

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
    public var updates: Source<Update<Change>> { return _state.source(retainingDelegate: self) }

    internal func start(_ signal: Signal<Update<Change>>) {
        assert(_connections == nil)
        let v1 = first.value
        let v2 = second.value
        _firstValue = v1
        _secondValue = v2
        _value = combinator(v1, v2)

        let c1 = first.updates.connect { [unowned self] update in self.apply(update) }
        let c2 = second.updates.connect { [unowned self] update in self.apply(update) }
        _connections = (c1, c2)
    }

    internal func stop(_ signal: Signal<Update<Change>>) {
        _connections!.0.disconnect()
        _connections!.1.disconnect()
        _value = nil
        _firstValue = nil
        _secondValue = nil
        _connections = nil
    }

    private func apply(_ update: ValueUpdate<Input1.Value>) {
        switch update {
        case .beginTransaction:
            _state.begin()
        case .change(let change):
            _firstValue = change.new
            let old = _value!
            let new = combinator(_firstValue!, _secondValue!)
            _value = new
            _state.send(ValueChange(from: old, to: new))
        case .endTransaction:
            _state.end()
        }
    }
    private func apply(_ update: ValueUpdate<Input2.Value>) {
        switch update {
        case .beginTransaction:
            _state.begin()
        case .change(let change):
            _secondValue = change.new
            let old = _value!
            let new = combinator(_firstValue!, _secondValue!)
            _value = new
            _state.send(ValueChange(from: old, to: new))
        case .endTransaction:
            self._state.end()
        }
    }
}

//MARK: Operations with observables of equatable values

public func == <A: ObservableValueType, B: ObservableValueType>(a: A, b: B) -> Observable<Bool>
where A.Value == B.Value, A.Value: Equatable {
    return a.combined(b, via: ==)
}

public func != <A: ObservableValueType, B: ObservableValueType>(a: A, b: B) -> Observable<Bool>
where A.Value == B.Value, A.Value: Equatable {
    return a.combined(b, via: !=)
}

//MARK: Operations with observables of comparable values

public func < <A: ObservableValueType, B: ObservableValueType>(a: A, b: B) -> Observable<Bool>
where A.Value == B.Value, A.Value: Comparable {
    return a.combined(b, via: <)
}

public func > <A: ObservableValueType, B: ObservableValueType>(a: A, b: B) -> Observable<Bool>
where A.Value == B.Value, A.Value: Comparable {
    return a.combined(b, via: >)
}

public func <= <A: ObservableValueType, B: ObservableValueType>(a: A, b: B) -> Observable<Bool>
where A.Value == B.Value, A.Value: Comparable {
    return a.combined(b, via: <=)
}

public func >= <A: ObservableValueType, B: ObservableValueType>(a: A, b: B) -> Observable<Bool>
where A.Value == B.Value, A.Value: Comparable {
    return a.combined(b, via: >=)
}

public func min<A: ObservableValueType, B: ObservableValueType, Value: Comparable>(_ a: A, _ b: B) -> Observable<Value>
where A.Value == Value, B.Value == Value {
    return a.combined(b, via: min)
}

public func max<A: ObservableValueType, B: ObservableValueType, Value: Comparable>(_ a: A, _ b: B) -> Observable<Value>
where A.Value == Value, B.Value == Value {
    return a.combined(b, via: max)
}

//MARK: Operations with observables of boolean values

public prefix func ! <O: ObservableValueType>(v: O) -> Observable<Bool> where O.Value == Bool {
    return v.map { !$0 }
}

public func && <A: ObservableValueType, B: ObservableValueType>(a: A, b: B) -> Observable<Bool>
where A.Value == Bool, B.Value == Bool {
    return a.combined(b, via: { a, b in a && b })
}

public func || <A: ObservableValueType, B: ObservableValueType>(a: A, b: B) -> Observable<Bool>
where A.Value == Bool, B.Value == Bool {
    return a.combined(b, via: { a, b in a || b })
}

//MARK: Operations with observables of integer arithmetic values

public prefix func - <O: ObservableValueType>(v: O) -> Observable<O.Value> where O.Value: SignedNumber {
    return v.map { -$0 }
}

public func + <A: ObservableValueType, B: ObservableValueType, Value: IntegerArithmetic>(a: A, b: B) -> Observable<Value>
where A.Value == Value, B.Value == Value {
    return a.combined(b, via: +)
}

public func - <A: ObservableValueType, B: ObservableValueType, Value: IntegerArithmetic>(a: A, b: B) -> Observable<Value>
where A.Value == Value, B.Value == Value {
    return a.combined(b, via: -)
}

public func * <A: ObservableValueType, B: ObservableValueType, Value: IntegerArithmetic>(a: A, b: B) -> Observable<Value>
where A.Value == Value, B.Value == Value {
    return a.combined(b, via: *)
}

public func / <A: ObservableValueType, B: ObservableValueType, Value: IntegerArithmetic>(a: A, b: B) -> Observable<Value>
where A.Value == Value, B.Value == Value {
    return a.combined(b, via: /)
}

public func % <A: ObservableValueType, B: ObservableValueType, Value: IntegerArithmetic>(a: A, b: B) -> Observable<Value>
where A.Value == Value, B.Value == Value {
    return a.combined(b, via: %)
}

//MARK: Operations with floating point values

public func + <A: ObservableValueType, B: ObservableValueType, Value: FloatingPoint>(a: A, b: B) -> Observable<Value>
where A.Value == Value, B.Value == Value {
    return a.combined(b, via: +)
}

public func - <A: ObservableValueType, B: ObservableValueType, Value: FloatingPoint>(a: A, b: B) -> Observable<Value>
where A.Value == Value, B.Value == Value {
    return a.combined(b, via: -)
}

public func * <A: ObservableValueType, B: ObservableValueType, Value: FloatingPoint>(a: A, b: B) -> Observable<Value>
where A.Value == Value, B.Value == Value {
    return a.combined(b, via: *)
}

public func / <A: ObservableValueType, B: ObservableValueType, Value: FloatingPoint>(a: A, b: B) -> Observable<Value>
where A.Value == Value, B.Value == Value {
    return a.combined(b, via: /)
}
