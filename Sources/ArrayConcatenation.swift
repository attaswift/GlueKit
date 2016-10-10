//
//  Concatenation.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-22.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableArrayType {
    public func concatenate<A: ObservableArrayType>(with other: A) -> ObservableArray<Element> where A.Element == Element {
        return ArrayConcatenation(first: self, second: other).observableArray
    }
}

public func +<A: ObservableArrayType, B: ObservableArrayType>(a: A, b: B) -> ObservableArray<A.Element> where A.Element == B.Element {
    return a.concatenate(with: b)
}

class ArrayConcatenation<First: ObservableArrayType, Second: ObservableArrayType>: ObservableArrayBase<First.Element>, SignalDelegate where First.Element == Second.Element {
    typealias Element = First.Element
    typealias Change = ArrayChange<Element>

    let first: First
    let second: Second

    private var changeSignal = OwningSignal<Change>()
    private var c1: Connection? = nil
    private var c2: Connection? = nil
    private var firstCount = 0
    private var secondCount = 0

    init(first: First, second: Second) {
        self.first = first
        self.second = second
    }

    override var isBuffered: Bool { return false }
    override subscript(index: Int) -> Element {
        let c = first.count
        if index < c {
            return first[index]
        }
        return second[index - c]
    }

    override subscript(bounds: Range<Int>) -> ArraySlice<Element> {
        let c = first.count
        if bounds.upperBound <= c {
            return first[bounds]
        }
        if bounds.lowerBound >= c {
            return second[bounds.lowerBound - c ..< bounds.upperBound - c]
        }
        return ArraySlice(first[bounds.lowerBound ..< c] + second[0 ..< bounds.upperBound - c])
    }
    override var value: [Element] { return first.value + second.value }
    override var count: Int { return first.count + second.count }
    override var changes: Source<Change> { return changeSignal.with(self).source }


    func start(_ signal: Signal<Change>) {
        firstCount = first.count
        secondCount = second.count
        c1 = first.changes.connect { change in
            precondition(self.firstCount == change.initialCount)
            self.firstCount = change.finalCount
            self.changeSignal.send(change.widen(startIndex: 0, initialCount: change.initialCount + self.secondCount))
        }
        c2 = second.changes.connect { change in
            precondition(self.secondCount == change.initialCount)
            self.secondCount = change.finalCount
            self.changeSignal.send(change.widen(startIndex: self.firstCount, initialCount: self.firstCount + change.initialCount))
        }
    }

    func stop(_ signal: Signal<Change>) {
        c1!.disconnect()
        c2!.disconnect()
        c1 = nil
        c2 = nil
        firstCount = 0
        secondCount = 0
    }
}
