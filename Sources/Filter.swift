//
//  Filter.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-12.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableArrayType {
    public func filter<TestResult: ObservableType where TestResult.Value == Bool>(test: Iterator.Element->TestResult) -> ObservableFilter<Iterator.Element, TestResult> {
        return ObservableFilter<Iterator.Element, TestResult>(parent: self, test: test)
    }
}

public class ObservableFilter<Element, TestResult: ObservableType where TestResult.Value == Bool>: SignalDelegate {
    typealias Change = ArrayChange<Element>

    private let parent: ObservableArray<Element>
    private let test: Element->TestResult

    private var changeSignal = OwningSignal<Change, ObservableFilter<Element, TestResult>>()

    private var parentConnection: Connection? = nil
    private var elementConnections: [Connection] = []

    private var active = false
    private var includedIndexes: Set<Int> = []

    public init<Parent: ObservableArrayType where Parent.Iterator.Element == Element>(parent: Parent, test: Element->TestResult) {
        self.parent = parent.observableArray
        self.test = test
    }


    public var count: Int {
        if active { return includedIndexes.count }

        var count = 0
        for element in parent.value {
            if test(element).value {
                count += 1
            }
        }
        return count
    }

    internal func start(signal: Signal<Change>) {
        active = true
        let elements = parent.value
        for i in 0..<elements.count {
            let e = elements[i]

            let test = self.test(e)

            if test.value {
                includedIndexes.insert(i)
            }

            let c = test.futureValues.connect { value in
                self.testResultDidChangeOnElement(e, result: value, signal: signal)
            }
            elementConnections.append(c)
        }
    }

    private func testResultDidChangeOnElement(element: Element, result: Bool, signal: Signal<Change>) {
        let i = indexOfElement(element)
        guard result != self.includedIndexes.contains(i) else { return }

        if result {
            self.includedIndexes.insert(i)
            let index = self.includedIndexes.reduce(0, combine: { s, i in 0 })
            signal.send(ArrayChange(initialCount: self.includedIndexes.count - 1, modification: .Insert(element, at: index)))
        }
        else {
            self.includedIndexes.remove(i)
        }
    }

    internal func stop(signal: Signal<Change>) {
        active = false
    }
}
