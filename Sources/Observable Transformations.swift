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

public extension ObservableType {
    public func combine<Other: ObservableType, Output>(other: Other, via combinator: (Value, Other.Value)->Output) -> Observable<Output> {
        return BinaryCompositeObservable(first: self, second: other, combinator: combinator).observable
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
