//
//  ObservableOperations.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-07.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

/// An Observable that is derived from another observable.
internal class TransformedObservable<Input: ObservableType, Output where Input.Change == SimpleChange<Input.ObservableValue>>: ObservableType, SignalOwner {
    internal typealias ObservableValue = Output
    internal typealias Change = SimpleChange<Output>

    private let input: Input
    private let transform: Input.Change.Value -> Output

    private var connection: Connection? = nil

    internal init(input: Input, transform: Input.Change.Value->Output) {
        self.input = input
        self.transform = transform
    }

    deinit {
        assert(connection == nil)
    }

    internal var value: ObservableValue { return transform(input.value) }
    internal var futureChanges: Source<Change> { return Signal<Change>(stronglyHeldOwner: self).source }

    internal func signalDidStart(signal: Signal<Change>) {
        assert(connection == nil)
        connection = input.futureChanges.connect { change in
            signal.send(SimpleChange(oldValue: self.transform(change.oldValue), newValue: self.transform(change.newValue)))
        }
    }

    internal func signalDidStop(signal: Signal<Change>) {
        assert(connection != nil)
        connection?.disconnect()
        connection = nil
    }
}

public extension ObservableType where Change == SimpleChange<ObservableValue> {
    public func map<Output>(transform: ObservableValue->Output) -> Observable<Output> {
        return TransformedObservable(input: self, transform: transform).observable
    }
}

/// An source that provides the distinct values of another observable.
internal class DistinctChangeSource<Value>: SourceType, SignalOwner {
    internal typealias Change = SimpleChange<Value>
    internal typealias SourceValue = Change

    private let input: Observable<Value>
    private let equalityTest: (Value, Value) -> Bool

    private var connection: Connection? = nil

    internal init
        <InputObservable: ObservableType where InputObservable.ObservableValue == Value, InputObservable.Change == SimpleChange<Value>>
        (input: InputObservable, equalityTest: (Value, Value)->Bool) {
        self.input = input.observable
        self.equalityTest = equalityTest
    }

    deinit {
        assert(connection == nil)
    }

    internal var value: Value { return input.value }
    internal var source: Source<Change> { return Signal<Change>(stronglyHeldOwner: self).source }

    internal func signalDidStart(signal: Signal<Change>) {
        assert(connection == nil)
        connection = input.futureChanges.connect { change in
            if !self.equalityTest(change.oldValue, change.newValue) {
                signal.send(change)
            }
        }
    }

    internal func signalDidStop(signal: Signal<Change>) {
        assert(connection != nil)
        connection?.disconnect()
        connection = nil
    }
}

public extension ObservableType where Change == SimpleChange<ObservableValue> {
    public func distinct(equalityTest: (ObservableValue, ObservableValue)->Bool) -> Observable<ObservableValue> {
        return Observable(getter: { self.value }, futureChanges: DistinctChangeSource(input: self, equalityTest: equalityTest).source)
    }
}

public extension ObservableType where Change == SimpleChange<ObservableValue>, ObservableValue: Equatable {
    public func distinct() -> Observable<ObservableValue> {
        return distinct(==)
    }
}

public extension UpdatableType where Change == SimpleChange<ObservableValue> {
    public func distinct(equalityTest: (ObservableValue, ObservableValue)->Bool) -> Updatable<ObservableValue> {
        return Updatable(
            getter: { self.value },
            setter: { v in self.value = v },
            futureChanges: DistinctChangeSource(input: self, equalityTest: equalityTest).source)
    }
}

public extension UpdatableType where Change == SimpleChange<ObservableValue>, ObservableValue: Equatable {
    public func distinct() -> Updatable<ObservableValue> {
        return distinct(==)
    }
}

/// An Observable that is calculated from two other observables.
public class BinaryCompositeObservable<Change1: ChangeType, Change2: ChangeType, Value>: ObservableType, SignalOwner {
    public typealias ObservableValue = Value
    public typealias Change = SimpleChange<Value>

    private let first: AnyObservable<Change1>
    private let second: AnyObservable<Change2>
    private let combinator: (Change1.Value, Change2.Value) -> Value

    public init<Input1: ObservableType, Input2: ObservableType where Input1.Change == Change1, Input2.Change == Change2>
        (first: Input1, second: Input2, combinator: (Change1.Value, Change2.Value) -> Value) {
            self.first = AnyObservable(first)
            self.second = AnyObservable(second)
            self.combinator = combinator
    }

    deinit {
        assert(connections.count == 0)
    }

    public var value: Value { return combinator(first.value, second.value) }
    public var futureChanges: Source<Change> { return Signal<Change>(stronglyHeldOwner: self).source }

    private var firstValue: Change1.Value? = nil
    private var secondValue: Change2.Value? = nil
    private var currentValue: Value? = nil
    private var connections: [Connection] = []

    internal func signalDidStart(signal: Signal<Change>) {
        assert(connections.count == 0)
        firstValue = first.value
        secondValue = second.value
        currentValue = combinator(firstValue!, secondValue!)
        let c1 = first.futureValues.connect { value in
            assert(self.currentValue != nil)
            let previousValue = self.currentValue!
            let currentValue = self.combinator(value, self.secondValue!)
            self.currentValue = currentValue

            signal.send(SimpleChange(oldValue: previousValue, newValue: currentValue))
        }
        let c2 = second.futureValues.connect { value in
            assert(self.currentValue != nil)
            let previousValue = self.currentValue!
            let currentValue = self.combinator(self.firstValue!, value)
            self.currentValue = currentValue

            signal.send(SimpleChange(oldValue: previousValue, newValue: currentValue))
        }
        connections = [c1, c2]
    }

    internal func signalDidStop(signal: Signal<Change>) {
        connections.forEach { $0.disconnect() }
        currentValue = nil
        connections = []
    }
}

public extension ObservableType {
    public func combine<Other: ObservableType, Output>(other: Other, via combinator: (Change.Value, Other.Change.Value)->Output) -> Observable<Output> {
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

public func min<Value: Comparable>(a: Observable<Value>, b: Observable<Value>) -> Observable<Value> {
    return a.combine(b, via: min)
}

public func max<Value: Comparable>(a: Observable<Value>, b: Observable<Value>) -> Observable<Value> {
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
