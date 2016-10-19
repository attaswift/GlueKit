//
//  Variable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-11-30.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

/// A variable implements `UpdatableValueType` by having internal storage to a value.
///
/// - SeeAlso: UnownedVariable<Value>, WeakVariable<Value>
///
public class Variable<Value>: AbstractUpdatableBase<Value> {
    public typealias Change = ValueChange<Value>

    private var _value: Value
    private var _state = TransactionState<Change>()

    /// Create a new variable with an initial value.
    public init(_ value: Value) {
        _value = value
    }

    /// The current value of the variable.
    public final override func get() -> Value {
        return _value
    }

    public final override func update(_ body: (Value) -> Value) {
        let old = _value
        _state.begin()
        _value = body(old)
        _state.send(Change(from: old, to: value))
        _state.end()
    }

    public final override var updates: ValueUpdateSource<Value> {
        return _state.source(retaining: self)
    }
}

/// An unowned variable contains an unowned reference to an object that can be read and updated. Updates are observable.
public class UnownedVariable<Value: AnyObject>: AbstractUpdatableBase<Value> {
    public typealias Change = ValueChange<Value>

    private unowned var _value: Value
    private var _state = TransactionState<Change>()

    /// Create a new variable with an initial value.
    public init(_ value: Value) {
        _value = value
    }

    /// The current value of the variable.
    public final override func get() -> Value {
        return _value
    }

    public final override func update(_ body: (Value) -> Value) {
        let old = _value
        _state.begin()
        _value = body(old)
        _state.send(Change(from: old, to: value))
        _state.end()
    }

    public final override var updates: ValueUpdateSource<Value> {
        return _state.source(retaining: self)
    }
}

/// A weak variable contains a weak reference to an object that can be read and updated. Updates are observable.
public class WeakVariable<Object: AnyObject>: AbstractUpdatableBase<Object?> {
    public typealias Value = Object?
    public typealias Change = ValueChange<Value>

    private weak var _value: Object?
    private var _state = TransactionState<Change>()

    /// Create a new variable with an initial value.
    public init(_ value: Value) {
        _value = value
    }

    /// The current value of the variable.
    public final override func get() -> Value {
        return _value
    }

    public final override func update(_ body: (Value) -> Value) {
        let old = _value
        _state.begin()
        _value = body(old)
        _state.send(Change(from: old, to: value))
        _state.end()
    }

    public final override var updates: ValueUpdateSource<Value> {
        return _state.source(retaining: self)
    }
}


//MARK: Experimental subclasses for specific types

// It would be so much more convenient if Swift allowed me to define these as extensions...

public final class BoolVariable: Variable<Bool>, ExpressibleByBooleanLiteral {
    public override init(_ value: Bool) {
        super.init(value)
    }
    public init(booleanLiteral value: BooleanLiteralType) {
        super.init(value)
    }

    public var boolValue: Bool { return self.value }
}

public final class IntVariable: Variable<Int>, ExpressibleByIntegerLiteral {
    public override init(_ value: Int) {
        super.init(value)
    }
    public init(integerLiteral value: IntegerLiteralType) {
        super.init(value)
    }
}

public final class FloatingPointVariable<F: FloatingPoint>: Variable<F>, ExpressibleByFloatLiteral where F: ExpressibleByFloatLiteral {
    public override init(_ value: F) {
        super.init(value)
    }
    public init(floatLiteral value: F.FloatLiteralType) {
        super.init(F(floatLiteral: value))
    }
}

public typealias FloatVariable = FloatingPointVariable<Float>
public typealias DoubleVariable = FloatingPointVariable<Double>

public final class StringVariable: Variable<String>, ExpressibleByStringLiteral {
    public override init(_ value: String) {
        super.init(value)
    }
    public init(unicodeScalarLiteral value: String.UnicodeScalarLiteralType) {
        super.init(value)
    }
    public init(extendedGraphemeClusterLiteral value: String.ExtendedGraphemeClusterLiteralType) {
        super.init(value)
    }
    public init(stringLiteral value: StringLiteralType) {
        super.init(value)
    }
}

public final class OptionalVariable<Wrapped>: Variable<Optional<Wrapped>>, ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        super.init(nil)
    }
}
