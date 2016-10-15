//
//  Variable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-11-30.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

/// A Storage allows read-write access to an individual piece of data.
public protocol StorageType {
    associatedtype Value
    var value: Value { get set }
}

/// `StrongStorage` directly contains a value, or a strong reference to a class instance.
public struct StrongStorage<Value>: StorageType {
    public var value: Value
    public init(_ value: Value) { self.value = value }
}

/// `WeakStorage` contains a weak reference to a class instance, as an optional value.
public struct WeakStorage<Object: AnyObject>: StorageType {
    public typealias Value = Object?
    public weak var value: Object?
    public init(_ value: Value) { self.value = value }
}

/// `UnownedStorage` containes an unowned reference to a class instance.
public struct UnownedStorage<Object: AnyObject>: StorageType {
    public typealias Value = Object
    public unowned var value: Object

    public init(_ value: Value) { self.value = value }
}

/// A variable implements `UpdatableValueType` by having internal storage to a value.
///
/// - SeeAlso: UnownedVariable<Value>, WeakVariable<Value>
///
public class Variable<Value>: AbstractUpdatableBase<Value> {
    public typealias Change = SimpleChange<Value>

    private var _value: Value
    private var _signal = ChangeSignal<Change>()

    /// Create a new variable with an initial value.
    internal init(_ value: Value) {
        _value = value
    }

    /// The current value of the variable.
    public final override func get() -> Value {
        return _value
    }

    public final override func update(_ body: (Value) -> Value) {
        if _signal.isChanging {
            _value = body(_value)
        }
        else {
            let old = _value
            _signal.willChange()
            _value = body(old)
            _signal.didChange(Change(from: old, to: value))
        }
    }

    public final override var changeEvents: Source<ChangeEvent<Change>> {
        return _signal.source(holding: self)
    }
}

/// An unowned variable contains an unowned reference to an object that can be read and updated. Updates are observable.
public class UnownedVariable<Value: AnyObject>: AbstractUpdatableBase<Value> {
    public typealias Change = SimpleChange<Value>

    private unowned var _value: Value
    private var _signal = ChangeSignal<Change>()

    /// Create a new variable with an initial value.
    internal init(_ value: Value) {
        _value = value
    }

    /// The current value of the variable.
    public final override func get() -> Value {
        return _value
    }

    public final override func update(_ body: (Value) -> Value) {
        if _signal.isChanging {
            _value = body(_value)
        }
        else {
            let old = _value
            _signal.willChange()
            _value = body(old)
            _signal.didChange(Change(from: old, to: value))
        }
    }

    public final override var changeEvents: Source<ChangeEvent<Change>> {
        return _signal.source(holding: self)
    }
}

/// A weak variable contains a weak reference to an object that can be read and updated. Updates are observable.
public class WeakVariable<Object: AnyObject>: AbstractUpdatableBase<Object?> {
    public typealias Value = Object?
    public typealias Change = SimpleChange<Value>

    private weak var _value: Object?
    private var _signal = ChangeSignal<Change>()

    /// Create a new variable with an initial value.
    internal init(_ value: Value) {
        _value = value
    }

    /// The current value of the variable.
    public final override func get() -> Value {
        return _value
    }

    public final override func update(_ body: (Value) -> Value) {
        if _signal.isChanging {
            _value = body(_value)
        }
        else {
            let old = _value
            _signal.willChange()
            _value = body(old)
            _signal.didChange(Change(from: old, to: value))
        }
    }

    public final override var changeEvents: Source<ChangeEvent<Change>> {
        return _signal.source(holding: self)
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

