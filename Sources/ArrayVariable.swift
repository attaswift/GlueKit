//
//  ArrayVariable.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-08.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation


public enum ArrayChange<Element>: ChangeType {
    public typealias Value = [Element]

    case Insert(Element, at: Int)
    case RemoveAt(Int)
    case ReplaceAt(Int, with: Element)
    case ReplaceRange(Range<Int>, with: [Element])
    case ReplaceAll([Element])

    public init(oldValue: Value, newValue: Value) {
        self = .ReplaceAll(newValue)
    }

    public func applyOn(value: Value) -> Value {
        var result = value
        result.apply(self)
        return result
    }
}

extension Array {
    mutating func apply(change: ArrayChange<Element>) {
        switch change {
        case .Insert(let element, at: let index):
            self.insert(element, atIndex: index)
        case .RemoveAt(let index):
            self.removeAtIndex(index)
        case .ReplaceAt(let index, with: let element):
            self[index] = element
        case .ReplaceRange(let range, with: let elements):
            self.replaceRange(range, with: elements)
        case .ReplaceAll(let elements):
            self = elements
        }
    }
}

public protocol ArrayObservableType: ObservableType {
    var observableCount: Observable<Int> { get }
}

public protocol ArrayUpdatableType: UpdatableType, ArrayObservableType, RangeReplaceableCollectionType {
}

public final class ArrayVariable<Element>: ArrayUpdatableType, ArrayLiteralConvertible {
    public typealias Change = ArrayChange<Element>
    public typealias SinkType = [Element]
    public typealias ArrayElement = Element

    private var _value: [Element]
    // These are created on demand and released immediately when unused
    private weak var _futureChanges: Signal<ArrayChange<Element>>? = nil
    private weak var _futureValues: Signal<[Element]>? = nil
    private weak var _futureCounts: Signal<SimpleChange<Int>>? = nil

    public init() {
        _value = []
    }
    public init(_ elements: [Element]) {
        _value = elements
    }
    public init(elements: Element...) {
        _value = elements
    }
    public init(arrayLiteral elements: Element...) {
        _value = elements
    }

    /// The current value of this ArrayVariable.
    public final var value: [Element] {
        get { return _value }
        set { setValue(newValue) }
    }

    /// A source that reports all future values of this variable.
    public final var futureChanges: Source<ArrayChange<Element>> {
        if let futureChanges = _futureChanges {
            return futureChanges.source
        }
        else {
            let signal = Signal<ArrayChange<Element>>()
            _futureChanges = signal
            return signal.source
        }
    }

    /// Update the value of this variable, and send the new value to all sinks that are currently connected.
    /// The sinks are only triggered if the value is not equal to the previous value, according to the equality test given in init.
    public final func setValue(value: [Element]) {
        _value = value
        _futureChanges?.send(.ReplaceAll(value))
    }


    public var count: Int {
        return value.count
    }

    private var futureCounts: Signal<SimpleChange<Int>> {
        if let futureCounts = _futureCounts {
            return futureCounts
        }
        else {
            var connection: Connection? = nil
            let signal = Signal<SimpleChange<Int>>(
                didConnectFirstSink: { signal in
                    var count = self.count
                    connection = self.futureChanges.connect { change in
                        let oldCount = count
                        switch change {
                        case .Insert(_, at: _):
                            count += 1
                        case .RemoveAt(_):
                            count -= 1
                        case .ReplaceAt(_, with: _):
                            break // Count doesn't change.
                        case .ReplaceRange(let range, with: let elements):
                            count += elements.count - range.count
                        case .ReplaceAll(let elements):
                            count = elements.count
                        }
                        signal.send(SimpleChange(oldValue: oldCount, newValue: count))
                    }
                },
                didDisconnectLastSink: { signal in
                    connection?.disconnect()
                    connection = nil
            })
            _futureCounts = signal
            return signal
        }
    }
    public var observableCount: Observable<Int> {
        return Observable(getter: { self.count }, futureChanges: { self.futureCounts.source })
    }

    public var futureValues: Source<[Element]> {
        if let signal = _futureValues {
            return signal.source
        }
        else {
            var connection: Connection? = nil
            let s = Signal<[Element]>(
                didConnectFirstSink: { s in
                    // TODO: check values sent when there're other sinks on self.signal
                    connection = self.futureValues.map { _ in self.value }.connect(s)
                },
                didDisconnectLastSink: { s in
                    connection?.disconnect()
                    connection = nil
            })
            _futureValues = s
            return s.source
        }
    }
}

extension ArrayVariable: MutableCollectionType {
    public typealias Generator = Array<Element>.Generator
    public typealias SubSequence = Array<Element>.SubSequence

    public var startIndex: Int { return value.startIndex }
    public var endIndex: Int { return value.endIndex }

    public func generate() -> Array<Element>.Generator {
        return value.generate()
    }

    public subscript(index: Int) -> Element {
        get {
            return value[index]
        }
        set {
            value[index] = newValue
            _futureChanges?.send(.ReplaceAt(index, with: newValue))
        }
    }

    public subscript(bounds: Range<Int>) -> SubSequence {
        get {
            return value[bounds]
        }
        set {
            value[bounds] = newValue
            _futureChanges?.send(.ReplaceRange(bounds, with: Array<Element>(newValue)))
        }
    }
}

extension ArrayVariable: RangeReplaceableCollectionType {
    public func replaceRange<C : CollectionType where C.Generator.Element == Generator.Element>(subRange: Range<Int>, with newElements: C) {
        value.replaceRange(subRange, with: newElements)
        _futureChanges?.send(.ReplaceRange(subRange, with: Array<Element>(newElements)))
    }

    // These have default implementations in terms of replaceRange, but doing them by hand makes for better change reports.

    public func append(newElement: Element) {
        self.insert(newElement, at: self.count)
    }

    public func insert(newElement: Element, at index: Int) {
        value.insert(newElement, atIndex: index)
        _futureChanges?.send(.Insert(newElement, at: index))
    }

    public func removeAtIndex(index: Int) -> Element {
        let result = value.removeAtIndex(index)
        _futureChanges?.send(.RemoveAt(index))
        return result
    }

    public func removeFirst() -> Element {
        let result = value.removeFirst()
        _futureChanges?.send(.RemoveAt(0))
        return result
    }

    public func removeLast() -> Element {
        let result = value.removeLast()
        _futureChanges?.send(.RemoveAt(self.count))
        return result
    }
    
    public func popLast() -> Element? {
        guard let result = value.popLast() else { return nil }
        _futureChanges?.send(.RemoveAt(self.count))
        return result
    }

    public func removeAll() {
        value.removeAll()
        _futureChanges?.send(.ReplaceAll([]))
    }

}



