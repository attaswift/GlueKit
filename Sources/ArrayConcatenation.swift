//
//  Concatenation.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-08-22.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

extension ObservableArrayType where Change == ArrayChange<Element> {
    public func concatenate<A: ObservableArrayType>(with other: A) -> AnyObservableArray<Element>
    where A.Element == Element, A.Change == ArrayChange<A.Element> {
        return ArrayConcatenation(first: self, second: other).anyObservableArray
    }
}

public func +<A: ObservableArrayType, B: ObservableArrayType>(a: A, b: B) -> AnyObservableArray<A.Element>
where A.Element == B.Element, A.Change == ArrayChange<A.Element>, B.Change == ArrayChange<B.Element> {
    return a.concatenate(with: b)
}

private struct FirstSink<First: ObservableArrayType, Second: ObservableArrayType>: UniqueOwnedSink
where First.Element == Second.Element, First.Change == ArrayChange<First.Element>, Second.Change == ArrayChange<Second.Element> {
    typealias Owner = ArrayConcatenation<First, Second>

    unowned(unsafe) let owner: Owner

    func receive(_ update: ArrayUpdate<First.Element>) {
        owner.applyFirst(update)
    }
}

private struct SecondSink<First: ObservableArrayType, Second: ObservableArrayType>: UniqueOwnedSink
where First.Element == Second.Element, First.Change == ArrayChange<First.Element>, Second.Change == ArrayChange<Second.Element> {
    typealias Owner = ArrayConcatenation<First, Second>

    unowned(unsafe) let owner: Owner

    func receive(_ update: ArrayUpdate<Second.Element>) {
        owner.applySecond(update)
    }
}

final class ArrayConcatenation<First: ObservableArrayType, Second: ObservableArrayType>: _BaseObservableArray<First.Element>
where First.Element == Second.Element, First.Change == ArrayChange<First.Element>, Second.Change == ArrayChange<Second.Element> {
    typealias Element = First.Element
    typealias Change = ArrayChange<Element>

    let first: First
    let second: Second

    private var firstCount = -1
    private var secondCount = -1

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

    override func activate() {
        firstCount = first.count
        secondCount = second.count
        first.updates.add(FirstSink(owner: self))
        second.updates.add(SecondSink(owner: self))
    }

    override func deactivate() {
        first.updates.remove(FirstSink(owner: self))
        second.updates.remove(SecondSink(owner: self))
        firstCount = -1
        secondCount = -1
    }

    func applyFirst(_ update: ArrayUpdate<Element>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            precondition(self.firstCount == change.initialCount)
            firstCount = change.finalCount
            sendChange(change.widen(startIndex: 0, initialCount: change.initialCount + self.secondCount))
        case .endTransaction:
            endTransaction()
        }
    }

    func applySecond(_ update: ArrayUpdate<Element>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            precondition(self.secondCount == change.initialCount)
            secondCount = change.finalCount
            sendChange(change.widen(startIndex: self.firstCount, initialCount: self.firstCount + change.initialCount))
        case .endTransaction:
            endTransaction()
        }
    }
}
