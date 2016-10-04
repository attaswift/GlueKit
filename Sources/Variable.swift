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

/// A property implements `UpdatableType` by accessing and updating its value in a piece of storage it owns.
/// The storage is configurable, and specified by the generic type parameter `Storage`.
///
/// Note that the storage must only be updated via the property's setters in order for update notifications to trigger 
/// correctly.
///
/// - SeeAlso: Variable<Value>, UnownedVariable<Value>, WeakVariable<Value>
///
public class Property<Storage: StorageType>: UpdatableType {
    public typealias Value = Storage.Value

    private var storage: Storage

    private lazy var signal = LazySignal<ValueChange<Value>>()

    /// Create a new variable with an initial value.
    internal init(_ storage: Storage) {
        self.storage = storage
    }

    /// The current value of the variable.
    public final var value: Value {
        get { return storage.value }
        set { setValue(newValue) }
    }

    public final var changes: Source<ValueChange<Value>> { return self.signal.source }

    /// Update the value of this variable, and send the new value to all sinks that are currently connected.
    /// The sinks are only triggered if the value is not equal to the previous value, according to the equality test given in init.
    public final func setValue(_ value: Value) {
        let old = storage.value
        storage.value = value
        signal.sendIfConnected(.init(from: old, to: value))
    }
}

/// A Variable contains a value that can be read and updated. Updates are observable.
public class Variable<Value>: Property<StrongStorage<Value>> {
    /// Create a new variable with an initial value.
    /// @param value: The initial value of the variable.
    public init(_ value: Value) {
        super.init(StrongStorage(value))
    }
}

/// An unowned variable contains an unowned reference to an object that can be read and updated. Updates are observable.
public class UnownedVariable<Value: AnyObject>: Property<UnownedStorage<Value>> {
    /// Create a new variable with an initial value.
    /// @param value: The initial value of the variable.
    public init(_ value: Value) {
        super.init(UnownedStorage(value))
    }
}

/// A weak variable contains a weak reference to an object that can be read and updated. Updates are observable.
public class WeakVariable<Object: AnyObject>: Property<WeakStorage<Object>> {
    /// Create a new variable with an initial value.
    /// @param value: The initial value of the variable.
    public init(_ value: Object?) {
        super.init(WeakStorage(value))
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

