//
//  DependentValue.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2017-04-23.
//  Copyright © 2015–2017 Károly Lőrentey.
//

infix operator <--

public func <-- <Value, Source: ObservableValueType>(target: DependentValue<Value>, source: Source) where Source.Value == Value {
    target.origin = source.anyObservableValue
}

public class DependentValue<Value> {
    private let setter: (Value) -> ()
    private var transactions: Int = 0
    private var pending: Value?

    internal var origin: AnyObservableValue<Value>? {
        didSet {
            receive(.beginTransaction)
            oldValue?.remove(Sink<Value>(owner: self))
            if let origin = origin {
                pending = origin.value
                origin.add(Sink<Value>(owner: self))
            }
            receive(.endTransaction)
        }
    }

    private struct Sink<Value>: UniqueOwnedSink {
        typealias Owner = DependentValue<Value>
        unowned(unsafe) let owner: Owner
        func receive(_ update: ValueUpdate<Value>) {
            owner.receive(update)
        }
    }

    public init(setter: @escaping (Value) -> ()) {
        self.setter = setter
        self.origin = nil
    }

    public init<Origin: ObservableValueType>(origin: Origin, setter: @escaping (Value) -> ()) where Origin.Value == Value {
        self.setter = setter
        self.origin = origin.anyObservableValue
        origin.add(Sink<Value>(owner: self))
    }

    deinit {
        origin?.remove(Sink<Value>(owner: self))
    }

    func receive(_ update: ValueUpdate<Value>) {
        switch update {
        case .beginTransaction:
            transactions += 1
        case .change(let change):
            pending = change.new
        case .endTransaction:
            transactions -= 1
            if transactions == 0, let pending = pending {
                self.pending = nil
                setter(pending)
            }
        }
    }
}
