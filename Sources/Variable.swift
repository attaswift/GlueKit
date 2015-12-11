//
//  Variable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-11-30.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

/// A Variable holds a value that can be read and updated. Updates to a variable are observable via any of its several sources.
public class Variable<Value>: UpdatableType {

    private var _value: Value
    private lazy var signal = LazySignal<Value>()

    /// Create a new variable with an initial value.
    /// @param value: The initial value of the variable.
    public init(_ value: Value) {
        self._value = value
    }

    /// The current value of the variable.
    public final var value: Value {
        get { return _value }
        set { setValue(newValue) }
    }

    /// A source that reports all future values of this variable.
    public final var futureValues: Source<Value> { return self.signal.source }

    /// Update the value of this variable, and send the new value to all sinks that are currently connected.
    /// The sinks are only triggered if the value is not equal to the previous value, according to the equality test given in init.
    public final func setValue(value: Value) {
        _value = value
        signal.sendIfConnected(value)
    }
}

public class UnownedVariable<Value: AnyObject>: UpdatableType {
    private unowned var _value: Value
    private lazy var signal = LazySignal<Value>()

    /// Create a new variable with an initial value.
    /// @param value: The initial value of the variable.
    public init(_ value: Value) {
        self._value = value
    }

    /// The current value of the variable.
    public final var value: Value {
        get { return _value }
        set { setValue(newValue) }
    }

    /// A source that reports all future values of this variable.
    public final var futureValues: Source<Value> { return self.signal.source }

    /// Update the value of this variable, and send the new value to all sinks that are currently connected.
    /// The sinks are only triggered if the value is not equal to the previous value, according to the equality test given in init.
    public final func setValue(value: Value) {
        _value = value
        signal.sendIfConnected(value)
    }
}

public class WeakVariable<Value: AnyObject>: UpdatableType {
    private weak var _value: Value? = nil
    private lazy var signal = LazySignal<Value?>()

    /// Create a new variable with an initial value.
    /// @param value: The initial value of the variable.
    public init(_ value: Value?) {
        self._value = value
    }

    /// The current value of the variable.
    public final var value: Value? {
        get { return _value }
        set { setValue(newValue) }
    }

    /// A source that reports all future values of this variable.
    public final var futureValues: Source<Value?> { return self.signal.source }

    /// Update the value of this variable, and send the new value to all sinks that are currently connected.
    /// The sinks are only triggered if the value is not equal to the previous value, according to the equality test given in init.
    public final func setValue(value: Value?) {
        _value = value
        signal.sendIfConnected(value)
    }
}


//MARK: Experimental subclasses for specific types

// It would be so much more convenient if Swift allowed me to define these as extensions...

public final class BoolVariable: Variable<Bool>, BooleanLiteralConvertible, BooleanType {
    public override init(_ value: Bool) {
        super.init(value)
    }
    public init(booleanLiteral value: BooleanLiteralType) {
        super.init(value)
    }

    public var boolValue: Bool { return self.value }
}

public final class IntVariable: Variable<Int>, IntegerLiteralConvertible {
    public override init(_ value: Int) {
        super.init(value)
    }
    public init(integerLiteral value: IntegerLiteralType) {
        super.init(value)
    }
}

public final class FloatVariable: Variable<Float>, FloatLiteralConvertible {
    public override init(_ value: Float) {
        super.init(value)
    }
    public init(floatLiteral value: FloatLiteralType) {
        super.init(Float(value))
    }
}

public final class DoubleVariable: Variable<Double>, FloatLiteralConvertible {
    public override init(_ value: Double) {
        super.init(value)
    }
    public init(floatLiteral value: FloatLiteralType) {
        super.init(value)
    }
}

public final class StringVariable: Variable<String>, StringLiteralConvertible {
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

public final class OptionalVariable<Wrapped>: Variable<Optional<Wrapped>>, NilLiteralConvertible {
    public init(nilLiteral: ()) {
        super.init(nil)
    }
}

