//
//  SetFilteringOnObservableBool.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-07.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

extension ObservableSetType {
    public func filter<TestResult: ObservableValueType>(_ isIncluded: @escaping (Element) -> TestResult) -> AnyObservableSet<Element> where TestResult.Value == Bool {
        return SetFilteringOnObservableBool<Self, TestResult>(parent: self, isIncluded: isIncluded).anyObservableSet
    }
}

private class SetFilteringOnObservableBool<Parent: ObservableSetType, TestResult: ObservableValueType>: _BaseObservableSet<Parent.Element> where TestResult.Value == Bool {
    typealias Element = Parent.Element
    typealias Change = SetChange<Element>

    private let parent: Parent
    private let isIncluded: (Element) -> TestResult

    private var matchingElements: Set<Element> = []
    private var elementSinks: Dictionary<AnySink<ValueUpdate<Bool>>, TestResult> = [:]

    init(parent: Parent, isIncluded: @escaping (Element) -> TestResult) {
        self.parent = parent
        self.isIncluded = isIncluded
    }

    override var isBuffered: Bool { return false }

    override var count: Int {
        if isConnected { return matchingElements.count }
        var count = 0
        for element in parent.value {
            if isIncluded(element).value {
                count += 1
            }
        }
        return count
    }

    override var value: Set<Element> {
        if isConnected { return matchingElements }
        return Set(self.parent.value.filter { isIncluded($0).value })
    }

    override func contains(_ member: Element) -> Bool {
        if isConnected { return matchingElements.contains(member) }
        return self.parent.contains(member) && isIncluded(member).value
    }

    override func isSubset(of other: Set<Element>) -> Bool {
        if isConnected { return matchingElements.isSubset(of: other) }
        for member in self.parent.value {
            guard isIncluded(member).value else { continue }
            guard other.contains(member) else { return false }
        }
        return true
    }

    override func isSuperset(of other: Set<Element>) -> Bool {
        if isConnected { return matchingElements.isSuperset(of: other) }
        for member in other {
            guard isIncluded(member).value && parent.contains(member) else { return false }
        }
        return true
    }

    override func startObserving() {
        for e in parent.value {
            let test = self.isIncluded(e)
            if test.value {
                matchingElements.insert(e)
            }
            let sink = elementSink(for: e)
            test.updates.add(sink)
            elementSinks[sink] = test
        }
        parent.updates.add(parentSink)
    }

    override func stopObserving() {
        parent.updates.remove(parentSink)
        for (sink, test) in elementSinks {
            test.updates.remove(sink)
        }
        elementSinks = [:]
        matchingElements = []
    }

    private var parentSink: AnySink<SetUpdate<Parent.Element>> {
        return MethodSink(owner: self, identifier: 0, method: SetFilteringOnObservableBool.applyParentUpdate).anySink
    }

    private func elementSink(for element: Parent.Element) -> AnySink<ValueUpdate<Bool>> {
        return MethodSinkWithContext(owner: self, method: SetFilteringOnObservableBool.applyElementUpdate, context: element).anySink
    }


    private func applyParentUpdate(_ update: SetUpdate<Parent.Element>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            var c = SetChange<Element>()
            for e in change.removed {
                let sink = elementSink(for: e)
                let test = elementSinks.removeValue(forKey: sink)!
                test.updates.remove(sink)
                if let old = self.matchingElements.remove(e) {
                    c.remove(old)
                }
            }
            for e in change.inserted {
                let test = self.isIncluded(e)
                let sink = elementSink(for: e)
                test.updates.add(sink)
                let old = elementSinks.updateValue(test, forKey: sink)
                precondition(old != nil)
                if test.value {
                    matchingElements.insert(e)
                    c.insert(e)
                }
            }
            if !c.isEmpty {
                sendChange(c)
            }
        case .endTransaction:
            endTransaction()
        }
    }

    private func applyElementUpdate(_ update: ValueUpdate<Bool>, from element: Parent.Element) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            if !change.old && change.new {
                matchingElements.insert(element)
                sendChange(SetChange(inserted: [element]))
            }
            else if change.old && !change.new {
                matchingElements.remove(element)
                sendChange(SetChange(removed: [element]))
            }
        case .endTransaction:
            endTransaction()
        }
    }
}
