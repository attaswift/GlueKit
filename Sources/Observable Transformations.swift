//
//  Observable Transformations.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-07.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

/// An Observable that is derived from another observable.
internal class TransformedObservable<Input: ObservableType, Value>: ObservableType, SignalDelegate {

    private let input: Input
    private let transform: Input.Value -> Value

    private var signal = OwningSignal<Value, TransformedObservable<Input, Value>>()
    private var connection: Connection? = nil

    internal init(input: Input, transform: Input.Value->Value) {
        self.input = input
        self.transform = transform
    }

    deinit {
        assert(connection == nil)
    }

    internal var value: Value { return transform(input.value) }
    internal var futureValues: Source<Value> { return signal.with(self).source }

    internal func start(signal: Signal<Value>) {
        assert(connection == nil)
        connection = input.futureValues.connect { value in
            signal.send(self.transform(value))
        }
    }

    internal func stop(signal: Signal<Value>) {
        assert(connection != nil)
        connection?.disconnect()
        connection = nil
    }
}

public extension ObservableType {
    /// Returns an observable that calculates `transform` on all current and future values of this observable.
    public func map<Output>(transform: Value->Output) -> Observable<Output> {
        return TransformedObservable(input: self, transform: transform).observable
    }
}

/// An source that provides the distinct values of another observable.
internal class DistinctValueSource<Input: ObservableType>: SignalDelegate {
    internal typealias Value = Input.Value

    private let input: Input
    private let equalityTest: (Value, Value) -> Bool

    private var signal = OwningSignal<Value, DistinctValueSource<Input>>()
    private var connection: Connection? = nil

    internal init(input: Input, equalityTest: (Value, Value)->Bool) {
        self.input = input
        self.equalityTest = equalityTest
    }

    deinit {
        assert(connection == nil)
    }

    internal var value: Value { return input.value }
    internal var source: Source<Value> { return signal.with(self).source }

    private var lastValue: Value? = nil

    internal func start(signal: Signal<Value>) {
        assert(connection == nil)
        lastValue = input.value
        connection = input.futureValues.connect { value in
            let send = !self.equalityTest(self.lastValue!, value)
            self.lastValue = value
            if send {
                signal.send(value)
            }
        }
    }

    internal func stop(signal: Signal<Value>) {
        assert(connection != nil)
        connection?.disconnect()
        connection = nil
        lastValue = nil
    }
}

public extension ObservableType {
    public func distinct(equalityTest: (Value, Value)->Bool) -> Observable<Value> {
        return Observable(
            getter: { self.value },
            futureValues: { DistinctValueSource(input: self, equalityTest: equalityTest).source })
    }
}

public extension ObservableType where Value: Equatable {
    public func distinct() -> Observable<Value> {
        return distinct(==)
    }
}

public extension UpdatableType {
    public func distinct(equalityTest: (Value, Value)->Bool) -> Updatable<Value> {
        return Updatable(
            getter: { self.value },
            setter: { v in self.value = v },
            futureValues: { DistinctValueSource(input: self, equalityTest: equalityTest).source })
    }
}

public extension UpdatableType where Value: Equatable {
    public func distinct() -> Updatable<Value> {
        return distinct(==)
    }
}

/// An Observable that is calculated from two other observables.
public class BinaryCompositeObservable<Input1: ObservableType, Input2: ObservableType, Value>: ObservableType, SignalDelegate {
    private let first: Input1
    private let second: Input2
    private let combinator: (Input1.Value, Input2.Value) -> Value
    private var signal = OwningSignal<Value, BinaryCompositeObservable<Input1, Input2, Value>>()

    public init(first: Input1, second: Input2, combinator: (Input1.Value, Input2.Value) -> Value) {
        self.first = first
        self.second = second
        self.combinator = combinator
    }

    deinit {
        assert(connections.count == 0)
    }

    public var value: Value { return combinator(first.value, second.value) }
    public var futureValues: Source<Value> { return signal.with(self).source }

    private var firstValue: Input1.Value? = nil
    private var secondValue: Input2.Value? = nil
    private var connections: [Connection] = []

    internal func start(signal: Signal<Value>) {
        assert(connections.count == 0)
        firstValue = first.value
        secondValue = second.value
        let c1 = first.futureValues.connect { value in
            assert(self.secondValue != nil)
            self.firstValue = value
            let result = self.combinator(value, self.secondValue!)
            signal.send(result)
        }
        let c2 = second.futureValues.connect { value in
            assert(self.firstValue != nil)
            self.secondValue = value
            let result = self.combinator(self.firstValue!, value)
            signal.send(result)
        }
        connections = [c1, c2]
    }

    internal func stop(signal: Signal<Value>) {
        connections.forEach { $0.disconnect() }
        firstValue = nil
        secondValue = nil
        connections = []
    }
}

/// An Updatable that is calculated from two other observables.
public class BinaryCompositeUpdatable<A: UpdatableType, B: UpdatableType>: BinaryCompositeObservable<A, B, (A.Value, B.Value)>, UpdatableType {
    public init(first: A, second: B) {
        super.init(first: first, second: second, combinator: { a, b in (a, b) })
    }

    public override var value: (A.Value, B.Value) {
        get { return super.value }
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
}

public extension ObservableType {
    public func combine<Other: ObservableType>(other: Other) -> Observable<(Value, Other.Value)> {
        return BinaryCompositeObservable(first: self, second: other, combinator: { ($0, $1) }).observable
    }

    public func combine<Other: ObservableType, Output>(other: Other, via combinator: (Value, Other.Value)->Output) -> Observable<Output> {
        return BinaryCompositeObservable(first: self, second: other, combinator: combinator).observable
    }
}

public func combine<O1: ObservableType, O2: ObservableType>(o1: O1, _ o2: O2) -> Observable<(O1.Value, O2.Value)> {
    return o1.combine(o2)
}

public func combine<O1: ObservableType, O2: ObservableType, O3: ObservableType>(o1: O1, _ o2: O2, _ o3: O3) -> Observable<(O1.Value, O2.Value, O3.Value)> {
    return o1.combine(o2).combine(o3, via: { a, b in (a.0, a.1, b) })
}

public func combine<O1: ObservableType, O2: ObservableType, O3: ObservableType, O4: ObservableType>(o1: O1, _ o2: O2, _ o3: O3, _ o4: O4) -> Observable<(O1.Value, O2.Value, O3.Value, O4.Value)> {

    return combine(o1, o2, o3).combine(o4, via: { a, b in (a.0, a.1, a.2, b) })
}

public func combine<O1: ObservableType, O2: ObservableType, O3: ObservableType, O4: ObservableType, O5: ObservableType>(o1: O1, _ o2: O2, _ o3: O3, _ o4: O4, _ o5: O5) -> Observable<(O1.Value, O2.Value, O3.Value, O4.Value, O5.Value)> {

    return combine(o1, o2, o3, o4).combine(o5, via: { a, b in (a.0, a.1, a.2, a.3, b) })
}

public func combine<O1: ObservableType, O2: ObservableType, O3: ObservableType, O4: ObservableType, O5: ObservableType, O6: ObservableType>(o1: O1, _ o2: O2, _ o3: O3, _ o4: O4, _ o5: O5, _ o6: O6) -> Observable<(O1.Value, O2.Value, O3.Value, O4.Value, O5.Value, O6.Value)> {

    return combine(o1, o2, o3, o4, o5).combine(o6, via: { a, b in (a.0, a.1, a.2, a.3, a.4, b) })
}

public extension UpdatableType {
    public func combine<Other: UpdatableType>(other: Other) -> Updatable<(Value, Other.Value)> {
        return BinaryCompositeUpdatable(first: self, second: other).updatable
    }
}

public func combine<O1: UpdatableType, O2: UpdatableType>(o1: O1, _ o2: O2) -> Updatable<(O1.Value, O2.Value)> {
    return o1.combine(o2)
}

public func combine<O1: UpdatableType, O2: UpdatableType, O3: UpdatableType>(o1: O1, _ o2: O2, _ o3: O3) -> Updatable<(O1.Value, O2.Value, O3.Value)> {
    let result = o1.combine(o2).combine(o3)
    return Updatable(
        observable: result.observable.map { a, b in (a.0, a.1, b) },
        setter: { v in result.value = ((v.0, v.1), v.2) })
}

public func combine<O1: UpdatableType, O2: UpdatableType, O3: UpdatableType, O4: UpdatableType>(o1: O1, _ o2: O2, _ o3: O3, _ o4: O4) -> Updatable<(O1.Value, O2.Value, O3.Value, O4.Value)> {
    let result = combine(o1, o2, o3).combine(o4)
    return Updatable(
        observable: result.observable.map { a, b in (a.0, a.1, a.2, b) },
        setter: { v in result.value = ((v.0, v.1, v.2), v.3) })
}

public func combine<O1: UpdatableType, O2: UpdatableType, O3: UpdatableType, O4: UpdatableType, O5: UpdatableType>(o1: O1, _ o2: O2, _ o3: O3, _ o4: O4, _ o5: O5) -> Updatable<(O1.Value, O2.Value, O3.Value, O4.Value, O5.Value)> {
    let result = combine(o1, o2, o3, o4).combine(o5)
    return Updatable(
        observable: result.observable.map { a, b in (a.0, a.1, a.2, a.3, b) },
        setter: { v in result.value = ((v.0, v.1, v.2, v.3), v.4) })
}

public func combine<O1: UpdatableType, O2: UpdatableType, O3: UpdatableType, O4: UpdatableType, O5: UpdatableType, O6: UpdatableType>(o1: O1, _ o2: O2, _ o3: O3, _ o4: O4, _ o5: O5, _ o6: O6) -> Updatable<(O1.Value, O2.Value, O3.Value, O4.Value, O5.Value, O6.Value)> {
    let result = combine(o1, o2, o3, o4, o5).combine(o6)
    return Updatable(
        observable: result.observable.map { a, b in (a.0, a.1, a.2, a.3, a.4, b) },
        setter: { v in result.value = ((v.0, v.1, v.2, v.3, v.4), v.5) })
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

public func min<Value: Comparable>(a: Observable<Value>, _ b: Observable<Value>) -> Observable<Value> {
    return a.combine(b, via: min)
}

public func max<Value: Comparable>(a: Observable<Value>, _ b: Observable<Value>) -> Observable<Value> {
    return a.combine(b, via: max)
}

//MARK: Operations with observables of boolean values

public prefix func !(v: Observable<Bool>) -> Observable<Bool> {
    return TransformedObservable(input: v, transform: !).observable
}

public func &&(a: Observable<Bool>, b: Observable<Bool>) -> Observable<Bool> {
    return BinaryCompositeObservable(first: a, second: b, combinator: { a, b in a && b }).observable
}

public func ||(a: Observable<Bool>, b: Observable<Bool>) -> Observable<Bool> {
    return BinaryCompositeObservable(first: a, second: b, combinator: { a, b in a || b }).observable
}

//MARK: Operations with observables of integer arithmetic values

public prefix func - <Num: SignedNumberType>(v: Observable<Num>) -> Observable<Num> {
    return v.map { -$0 }
}

public func + <Num: IntegerArithmeticType>(a: Observable<Num>, b: Observable<Num>) -> Observable<Num> {
    return a.combine(b, via: +)
}

public func - <Num: IntegerArithmeticType>(a: Observable<Num>, b: Observable<Num>) -> Observable<Num> {
    return a.combine(b, via: -)
}

public func * <Num: IntegerArithmeticType>(a: Observable<Num>, b: Observable<Num>) -> Observable<Num> {
    return a.combine(b, via: *)
}

public func / <Num: IntegerArithmeticType>(a: Observable<Num>, b: Observable<Num>) -> Observable<Num> {
    return a.combine(b, via: /)
}

public func % <Num: IntegerArithmeticType>(a: Observable<Num>, b: Observable<Num>) -> Observable<Num> {
    return a.combine(b, via: %)
}

//MARK: Operations with Double values

public prefix func -(v: Observable<Double>) -> Observable<Double> {
    return v.map { -$0 }
}

public func +(a: Observable<Double>, b: Observable<Double>) -> Observable<Double> {
    return a.combine(b, via: +)
}

public func -(a: Observable<Double>, b: Observable<Double>) -> Observable<Double> {
    return a.combine(b, via: -)
}

public func *(a: Observable<Double>, b: Observable<Double>) -> Observable<Double> {
    return a.combine(b, via: *)
}

public func /(a: Observable<Double>, b: Observable<Double>) -> Observable<Double> {
    return a.combine(b, via: /)
}

public func %(a: Observable<Double>, b: Observable<Double>) -> Observable<Double> {
    return a.combine(b, via: %)
}

//MARK: Operations with CGFloat values

#if USE_COREGRAPHICS

public prefix func -(v: Observable<CGFloat>) -> Observable<CGFloat> {
    return v.map { -$0 }
}

public func +(a: Observable<CGFloat>, b: Observable<CGFloat>) -> Observable<CGFloat> {
    return a.combine(b, via: +)
}

public func -(a: Observable<CGFloat>, b: Observable<CGFloat>) -> Observable<CGFloat> {
    return a.combine(b, via: -)
}

public func *(a: Observable<CGFloat>, b: Observable<CGFloat>) -> Observable<CGFloat> {
    return a.combine(b, via: *)
}

public func /(a: Observable<CGFloat>, b: Observable<CGFloat>) -> Observable<CGFloat> {
    return a.combine(b, via: /)
}

public func %(a: Observable<CGFloat>, b: Observable<CGFloat>) -> Observable<CGFloat> {
    return a.combine(b, via: %)
}

#endif
