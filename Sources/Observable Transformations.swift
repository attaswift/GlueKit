//
//  Observable Transformations.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-07.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

// MARK: Buffered

internal class BufferedObservable<Base: ObservableType>: ObservableType {
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

    var futureValues: Source<Base.Value> {
        return base.futureValues
    }
}

extension ObservableType {
    public func buffered() -> Observable<Value> {
        return BufferedObservable(self).observable
    }
}

// MARK: Map

/// An Observable that is derived from another observable.
internal class TransformedObservable<Input: ObservableType, Value>: ObservableType, SignalDelegate {

    fileprivate let input: Input
    fileprivate let transform: (Input.Value) -> Value

    private var signal = OwningSignal<Value>()
    private var connection: Connection? = nil

    internal init(input: Input, transform: @escaping (Input.Value) -> Value) {
        self.input = input
        self.transform = transform
    }

    deinit {
        assert(connection == nil)
    }

    internal var value: Value { return transform(input.value) }
    internal var futureValues: Source<Value> { return signal.with(self).source }

    internal func start(_ signal: Signal<Value>) {
        assert(connection == nil)
        connection = input.futureValues.connect { value in
            signal.send(self.transform(value))
        }
    }

    internal func stop(_ signal: Signal<Value>) {
        assert(connection != nil)
        connection?.disconnect()
        connection = nil
    }
}

public extension ObservableType {
    /// Returns an observable that calculates `transform` on all current and future values of this observable.
    public func map<Output>(_ transform: @escaping (Value) -> Output) -> Observable<Output> {
        return TransformedObservable(input: self, transform: transform).observable
    }
}

class TransformedUpdatable<Input: UpdatableType, Value>: TransformedObservable<Input, Value>, UpdatableType {
    private let inverseTransform: (Value) -> Input.Value

    internal init(input: Input, transform: @escaping (Input.Value) -> Value, inverseTransform: @escaping (Value) -> Input.Value) {
        self.inverseTransform = inverseTransform
        super.init(input: input, transform: transform)
    }

    override var value: Value {
        get { return transform(input.value) }
        set { input.value = inverseTransform(newValue) }
    }
}

extension UpdatableType {
    public func map<Output>(_ transform: @escaping (Value) -> Output, inverse: @escaping (Output) -> Value) -> Updatable<Output> {
        return TransformedUpdatable(input: self, transform: transform, inverseTransform: inverse).updatable
    }
}

// MARK: Distinct

/// An source that provides the distinct values of another observable.
internal class DistinctObservable<Input: ObservableType>: ObservableType, SignalDelegate {
    internal typealias Value = Input.Value

    fileprivate let input: Input
    fileprivate let equalityTest: (Value, Value) -> Bool

    private var signal = OwningSignal<Value>()
    private var connection: Connection? = nil

    internal init(input: Input, equalityTest: @escaping (Value, Value) -> Bool) {
        self.input = input
        self.equalityTest = equalityTest
    }

    deinit {
        assert(connection == nil)
    }

    internal var value: Value { return input.value }
    internal var futureValues: Source<Value> { return signal.with(self).source }

    private var lastValue: Value? = nil

    internal func start(_ signal: Signal<Value>) {
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

    internal func stop(_ signal: Signal<Value>) {
        assert(connection != nil)
        connection?.disconnect()
        connection = nil
        lastValue = nil
    }
}

class DistinctUpdatable<Input: UpdatableType>: UpdatableType, SignalDelegate {
    internal typealias Value = Input.Value

    fileprivate let input: Input
    fileprivate let equalityTest: (Value, Value) -> Bool

    private var signal = OwningSignal<Value>()
    private var connection: Connection? = nil

    internal init(input: Input, equalityTest: @escaping (Value, Value) -> Bool) {
        self.input = input
        self.equalityTest = equalityTest
    }

    deinit {
        assert(connection == nil)
    }

    internal var value: Value {
        get { return input.value }
        set {
            if !equalityTest(input.value, newValue) {
                input.value = newValue
            }
        }
    }

    internal var futureValues: Source<Value> { return signal.with(self).source }

    private var lastValue: Value? = nil

    internal func start(_ signal: Signal<Value>) {
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

    internal func stop(_ signal: Signal<Value>) {
        assert(connection != nil)
        connection?.disconnect()
        connection = nil
        lastValue = nil
    }
}

public extension ObservableType {
    public func distinct(_ equalityTest: @escaping (Value, Value) -> Bool) -> Observable<Value> {
        return DistinctObservable(input: self, equalityTest: equalityTest).observable
    }
}

public extension ObservableType where Value: Equatable {
    public func distinct() -> Observable<Value> {
        return distinct(==)
    }
}

public extension UpdatableType {
    public func distinct(_ equalityTest: @escaping (Value, Value) -> Bool) -> Updatable<Value> {
        return DistinctUpdatable(input: self, equalityTest: equalityTest).updatable
    }
}

public extension UpdatableType where Value: Equatable {
    public func distinct() -> Updatable<Value> {
        return distinct(==)
    }
}

// MARK: Combine

/// An Observable that is calculated from two other observables.
public final class BinaryCompositeObservable<Input1: ObservableType, Input2: ObservableType, Value>: ObservableType, SignalDelegate {
    private let first: Input1
    private let second: Input2
    private let combinator: (Input1.Value, Input2.Value) -> Value
    private var signal = OwningSignal<Value>()

    public init(first: Input1, second: Input2, combinator: @escaping (Input1.Value, Input2.Value) -> Value) {
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

    internal func start(_ signal: Signal<Value>) {
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

    internal func stop(_ signal: Signal<Value>) {
        connections.forEach { $0.disconnect() }
        firstValue = nil
        secondValue = nil
        connections = []
    }
}

public extension ObservableType {
    public func combine<Other: ObservableType>(_ other: Other) -> Observable<(Value, Other.Value)> {
        return BinaryCompositeObservable(first: self, second: other, combinator: { ($0, $1) }).observable
    }

    public func combine<Other: ObservableType, Output>(_ other: Other, via combinator: @escaping (Value, Other.Value) -> Output) -> Observable<Output> {
        return BinaryCompositeObservable(first: self, second: other, combinator: combinator).observable
    }
}

public func combine<O1: ObservableType, O2: ObservableType>(_ o1: O1, _ o2: O2) -> Observable<(O1.Value, O2.Value)> {
    return o1.combine(o2)
}

public func combine<O1: ObservableType, O2: ObservableType, O3: ObservableType>(_ o1: O1, _ o2: O2, _ o3: O3) -> Observable<(O1.Value, O2.Value, O3.Value)> {
    return o1.combine(o2).combine(o3, via: { a, b in (a.0, a.1, b) })
}

public func combine<O1: ObservableType, O2: ObservableType, O3: ObservableType, O4: ObservableType>(_ o1: O1, _ o2: O2, _ o3: O3, _ o4: O4) -> Observable<(O1.Value, O2.Value, O3.Value, O4.Value)> {

    return combine(o1, o2, o3).combine(o4, via: { a, b in (a.0, a.1, a.2, b) })
}

public func combine<O1: ObservableType, O2: ObservableType, O3: ObservableType, O4: ObservableType, O5: ObservableType>(_ o1: O1, _ o2: O2, _ o3: O3, _ o4: O4, _ o5: O5) -> Observable<(O1.Value, O2.Value, O3.Value, O4.Value, O5.Value)> {

    return combine(o1, o2, o3, o4).combine(o5, via: { a, b in (a.0, a.1, a.2, a.3, b) })
}

public func combine<O1: ObservableType, O2: ObservableType, O3: ObservableType, O4: ObservableType, O5: ObservableType, O6: ObservableType>(_ o1: O1, _ o2: O2, _ o3: O3, _ o4: O4, _ o5: O5, _ o6: O6) -> Observable<(O1.Value, O2.Value, O3.Value, O4.Value, O5.Value, O6.Value)> {

    return combine(o1, o2, o3, o4, o5).combine(o6, via: { a, b in (a.0, a.1, a.2, a.3, a.4, b) })
}


/// An Updatable that is a composite of two other updatables.
internal final class CompositeUpdatable<A: UpdatableType, B: UpdatableType>: UpdatableType, SignalDelegate {
    typealias Value = (A.Value, B.Value)
    private let first: A
    private let second: B
    private var signal = OwningSignal<Value>()

    private var firstValue: A.Value? = nil
    private var secondValue: B.Value? = nil
    private var connections: [Connection] = []

    init(first: A, second: B) {
        self.first = first
        self.second = second
    }

    final var futureValues: Source<Value> { return signal.with(self).source }

    final var value: Value {
        get {
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

    final func start(_ signal: Signal<Value>) {
        assert(connections.count == 0)
        firstValue = first.value
        secondValue = second.value
        let c1 = first.futureValues.connect { value in
            guard let secondValue = self.secondValue else { fatalError() }
            self.firstValue = value
            let result = (value, secondValue)
            signal.send(result)
        }
        let c2 = second.futureValues.connect { value in
            guard let firstValue = self.firstValue else { fatalError() }
            self.secondValue = value
            let result = (firstValue, value)
            signal.send(result)
        }
        connections = [c1, c2]
    }

    final func stop(_ signal: Signal<Value>) {
        connections.forEach { $0.disconnect() }
        firstValue = nil
        secondValue = nil
        connections = []
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
    return TransformedObservable(input: v, transform: !).observable
}

public func &&(a: Observable<Bool>, b: Observable<Bool>) -> Observable<Bool> {
    return BinaryCompositeObservable(first: a, second: b, combinator: { a, b in a && b }).observable
}

public func ||(a: Observable<Bool>, b: Observable<Bool>) -> Observable<Bool> {
    return BinaryCompositeObservable(first: a, second: b, combinator: { a, b in a || b }).observable
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

#endif
