//
//  Variable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-11-30.
//  Copyright © 2015–2017 Károly Lőrentey.
//

/// A variable implements `UpdatableValueType` by having internal storage to a value.
///
/// - SeeAlso: UnownedVariable<Value>, WeakVariable<Value>
///
open class Variable<Value>: _BaseUpdatableValue<Value> {
    public typealias Change = ValueChange<Value>

    private var _value: Value

    /// Create a new variable with an initial value.
    public init(_ value: Value) {
        _value = value
    }
    override func rawGetValue() -> Value {
        return _value
    }
    override func rawSetValue(_ value: Value) {
        _value = value
    }
}

/// An unowned variable contains an unowned reference to an object that can be read and updated. Updates are observable.
public class UnownedVariable<Value: AnyObject>: _BaseUpdatableValue<Value> {
    public typealias Change = ValueChange<Value>

    private unowned var _value: Value

    /// Create a new variable with an initial value.
    public init(_ value: Value) {
        _value = value
    }
    override func rawGetValue() -> Value {
        return _value
    }
    override func rawSetValue(_ value: Value) {
        _value = value
    }
}

/// A weak variable contains a weak reference to an object that can be read and updated. Updates are observable.
public class WeakVariable<Object: AnyObject>: _BaseUpdatableValue<Object?> {
    public typealias Value = Object?
    public typealias Change = ValueChange<Value>

    private weak var _value: Object?

    /// Create a new variable with a `nil` initial value.
    public override init() {
        _value = nil
        super.init()
    }

    /// Create a new variable with an initial value.
    public init(_ value: Value) {
        _value = value
        super.init()
    }

    override func rawGetValue() -> Value {
        return _value
    }
    override func rawSetValue(_ value: Value) {
        _value = value
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
    public override init(_ value: Wrapped?) {
        super.init(value)
    }

    public init(nilLiteral: ()) {
        super.init(nil)
    }
}
