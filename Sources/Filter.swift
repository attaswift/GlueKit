//
//  Filter.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-12.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableSetType {
    public typealias ElementFilter = @escaping (Element) -> Bool
    public func filtered(test: ElementFilter) -> ObservableSet<Element> {
        return ObservableSetSimpleFilter<Self>(parent: self, test: test).observableSet
    }

    public func filtered<TestResult: ObservableType>(test: @escaping (Element) -> TestResult) -> ObservableSet<Element> where TestResult.Value == Bool {
        return ObservableSetComplexFilter<Self, TestResult>(parent: self, test: test).observableSet
    }

    public func filtered(test: Observable<ElementFilter?>) -> ObservableSet<Element> {
        let reference = ObservableSetReference<Element>()
        let connection = test.values.connect { testValue in
            if let testValue = testValue {
                reference.retarget(to: self.filtered(test: testValue))
            }
            else {
                reference.retarget(to: self)
            }
        }
        return reference.observableSet.holding(connection)
    }
}

private class ObservableSetSimpleFilter<Parent: ObservableSetType>: ObservableSetType, SignalDelegate {
    public typealias Element = Parent.Element
    public typealias Change = SetChange<Element>

    private let parent: Parent
    private let test: (Element) -> Bool

    private var changeSignal = OwningSignal<Change>()

    private var active = false
    private var parentConnection: Connection? = nil
    private var matchingElements: Set<Element> = []

    init(parent: Parent, test: @escaping (Element) -> Bool) {
        self.parent = parent
        self.test = test
    }

    var isBuffered: Bool { return false }
    var value: Set<Element> {
        if active { return matchingElements }
        return Set(self.parent.value.filter(test))
    }
    var futureChanges: Source<SetChange<Parent.Element>> { return changeSignal.with(self).source }
    func contains(_ member: Element) -> Bool {
        if active { return matchingElements.contains(member) }
        return self.parent.contains(member) && test(member)
    }

    func isSubset(of other: Set<Element>) -> Bool {
        if active { return matchingElements.isSubset(of: other) }
        for member in self.parent.value {
            guard test(member) else { continue }
            guard other.contains(member) else { return false }
        }
        return true
    }

    func isSuperset(of other: Set<Element>) -> Bool {
        if active { return matchingElements.isSuperset(of: other) }
        for member in other {
            guard test(member) && parent.contains(member) else { return false }
        }
        return true
    }

    var count: Int {
        if active { return matchingElements.count }

        var count = 0
        for element in parent.value {
            if test(element) {
                count += 1
            }
        }
        return count
    }

    internal func start(_ signal: Signal<Change>) {
        active = true
        for e in parent.value {
            if test(e) {
                matchingElements.insert(e)
            }
        }
        parentConnection = parent.futureChanges.connect { change in
            var c = SetChange<Element>()
            for e in change.removed {
                if let old = self.matchingElements.remove(e) {
                    c.remove(old)
                }
            }
            for e in change.inserted {
                if self.test(e) {
                    self.matchingElements.insert(e)
                    c.insert(e)
                }
            }
            if !c.isEmpty {
                self.changeSignal.send(c)
            }
        }
    }

    internal func stop(_ signal: Signal<Change>) {
        active = false
        parentConnection?.disconnect()
        parentConnection = nil
        matchingElements = []
    }
}

private class ObservableSetComplexFilter<Parent: ObservableSetType, TestResult: ObservableType>: ObservableSetType, SignalDelegate where TestResult.Value == Bool {
    typealias Element = Parent.Element
    typealias Change = SetChange<Element>
    typealias SignalValue = Change

    private let parent: Parent
    private let test: (Element) -> TestResult

    private var changeSignal = OwningSignal<Change>()

    private var active = false
    private var parentConnection: Connection? = nil
    private var elementConnections: [Element: Connection] = [:]
    private var matchingElements: Set<Element> = []

    init(parent: Parent, test: @escaping (Element) -> TestResult) {
        self.parent = parent
        self.test = test
    }

    var isBuffered: Bool { return false }

    var value: Set<Element> {
        if active { return matchingElements }
        return Set(self.parent.value.filter { test($0).value })
    }

    var futureChanges: Source<SetChange<Parent.Element>> { return changeSignal.with(self).source }

    func contains(_ member: Element) -> Bool {
        if active { return matchingElements.contains(member) }
        return self.parent.contains(member) && test(member).value
    }

    func isSubset(of other: Set<Element>) -> Bool {
        if active { return matchingElements.isSubset(of: other) }
        for member in self.parent.value {
            guard test(member).value else { continue }
            guard other.contains(member) else { return false }
        }
        return true
    }

    func isSuperset(of other: Set<Element>) -> Bool {
        if active { return matchingElements.isSuperset(of: other) }
        for member in other {
            guard test(member).value && parent.contains(member) else { return false }
        }
        return true
    }

    var count: Int {
        if active { return matchingElements.count }

        var count = 0
        for element in parent.value {
            if test(element).value {
                count += 1
            }
        }
        return count
    }

    internal func start(_ signal: Signal<Change>) {
        active = true
        for e in parent.value {
            let test = self.test(e)
            if test.value {
                matchingElements.insert(e)
            }
            let c = test.futureValues.connect { value in
                self.testResultDidChange(on: e, result: value, signal: signal)
            }
            elementConnections[e] = c
        }
        parentConnection = parent.futureChanges.connect { change in
            var c = SetChange<Element>()
            for e in change.removed {
                self.elementConnections.removeValue(forKey: e)!.disconnect()
                if let old = self.matchingElements.remove(e) {
                    c.remove(old)
                }
            }
            for e in change.inserted {
                let test = self.test(e)
                self.elementConnections[e] = test.futureValues.connect { value in
                    self.testResultDidChange(on: e, result: value, signal: signal)
                }
                if test.value {
                    self.matchingElements.insert(e)
                    c.insert(e)
                }
            }
            if !c.isEmpty {
                self.changeSignal.send(c)
            }
        }
    }

    internal func stop(_ signal: Signal<Change>) {
        active = false
        parentConnection?.disconnect()
        parentConnection = nil
        elementConnections.forEach { $0.1.disconnect() }
        elementConnections = [:]
        matchingElements = []
    }

    private func testResultDidChange(on element: Parent.Element, result: Bool, signal: Signal<Change>) {
        let old = matchingElements.contains(element)
        if result && !old {
            matchingElements.insert(element)
            signal.send(SetChange(inserted: [element]))
        }
        else if !result && old {
            matchingElements.remove(element)
            signal.send(SetChange(removed: [element]))
        }
    }
}
