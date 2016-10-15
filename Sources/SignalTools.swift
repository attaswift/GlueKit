//
//  SignalTools.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-09-27.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

/// This is a wrapper around a lazily created Signal that holds a strong reference to its delegate.
///
/// Using this in your implementation of a source or observable helps satisfying GlueKit's two conventions:
///
/// - Dependants hold strong references to their dependencies
/// - Dependants only activate their dependencies while someone is interested in them
///
internal struct OwningSignal<Value> {
    internal typealias SourceValue = Value

    private weak var signal: Signal<Value>? = nil

    internal init() {
    }

    internal mutating func with(retained container: AnyObject) -> Signal<Value> {
        if let s = signal {
            return s
        }
        let s = Signal<Value>(start: { [container] _ in _ = container }, stop: { _ in })
        self.signal = s
        return s
    }

    internal mutating func with<Delegate: SignalDelegate>(_ delegate: Delegate) -> Signal<Value> where Delegate.SignalValue == Value {
        if let s = signal {
            return s
        }
        let s = Signal<Value>(stronglyHeldDelegate: delegate)
        self.signal = s
        return s
    }

    internal var isConnected: Bool {
        guard let s = signal else { return false }
        return s.isConnected
    }

    /// Send value to the signal (if it exists).
    internal func send(_ value: Value) {
        signal?.send(value)
    }

    internal func sendLater(_ value: Value) {
        signal?.sendLater(value)
    }

    internal func sendNow() {
        signal?.sendNow()
    }

    internal func sendIfConnected(_ value: @autoclosure (Void) -> Value) {
        if let s = signal, s.isConnected {
            s.send(value())
        }
    }
}

internal struct LazySignal<Value> { // Can't be SourceType because connect is mutating.
    internal typealias SourceValue = Value

    private weak var _signal: Signal<Value>? = nil

    internal init() {
    }

    internal var signal: Signal<Value> {
        mutating get {
            if let s = _signal {
                return s
            }
            else {
                let s = Signal<Value>()
                _signal = s
                return s
            }
        }
    }

    internal var isConnected: Bool {
        if let s = _signal, s.isConnected {
            return true
        }
        return false
    }

    /// Send value to the signal (if it exists).
    internal func send(_ value: Value) {
        _signal?.send(value)
    }

    internal func sendLater(_ value: Value) {
        _signal?.sendLater(value)
    }

    internal func sendNow() {
        _signal?.sendNow()
    }

    internal func sendIfConnected(_ value: @autoclosure (Void) -> Value) {
        if let s = _signal, s.isConnected {
            s.send(value())
        }
    }

    internal mutating func connect(_ sink: Sink<Value>) -> Connection {
        return self.signal.connect(sink)
    }

    internal mutating func connect<S: SinkType>(_ sink: S) -> Connection where S.SinkValue == Value {
        return signal.connect(sink)
    }

    internal var source: Source<Value> {
        mutating get { return self.signal.source }
    }
}
