//
//  ObservableSetTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-10.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
@testable import GlueKit

class TestObservableSet<Element: Hashable>: _AbstractObservableSet<Element>, TransactionalThing {
    var _signal: TransactionalSignal<SetChange<Element>>? = nil
    var _transactionCount: Int = 0
    private var _value: Set<Element>

    init(_ value: Set<Element>) {
        self._value = value
    }

    override var value: Set<Element> { return _value }

    override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        signal.add(sink)
    }

    @discardableResult
    override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        return signal.remove(sink)
    }

    func apply(_ change: Change) {
        if change.isEmpty { return }
        beginTransaction()
        _value.subtract(change.removed)
        _value.formUnion(change.inserted)
        sendChange(change)
        endTransaction()
    }
}

private class TestObservableSet2<Element: Hashable>: ObservableSetType, TransactionalThing {
    typealias Change = SetChange<Element>

    var _signal: TransactionalSignal<SetChange<Element>>? = nil
    var _transactionCount: Int = 0
    var _value: Set<Element>

    init(_ value: Set<Element>) {
        self._value = value
    }

    var value: Set<Element> { return _value }

    func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        signal.add(sink)
    }

    @discardableResult
    func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        return signal.remove(sink)
    }

    func apply(_ change: Change) {
        if change.isEmpty { return }
        beginTransaction()
        _value.subtract(change.removed)
        _value.formUnion(change.inserted)
        sendChange(change)
        endTransaction()
    }
}


private class TestUpdatableSet<Element: Hashable>: _AbstractUpdatableSet<Element>, TransactionalThing {
    var _signal: TransactionalSignal<SetChange<Element>>? = nil
    var _transactionCount: Int = 0
    var _value: Set<Element>

    init(_ value: Set<Element>) {
        self._value = value
    }

    override var value: Set<Element> {
        get { return _value }
        set { self.apply(SetChange(removed: _value, inserted: newValue)) }
    }

    override func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        signal.add(sink)
    }

    @discardableResult
    override func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        return signal.remove(sink)
    }

    override func apply(_ update: Update<Change>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            _value.subtract(change.removed)
            _value.formUnion(change.inserted)
            sendChange(change)
        case .endTransaction:
            endTransaction()
        }
    }
}

private class TestUpdatableSet2<Element: Hashable>: UpdatableSetType, TransactionalThing {
    typealias Change = SetChange<Element>

    var _signal: TransactionalSignal<SetChange<Element>>? = nil
    var _transactionCount: Int = 0
    var _value: Set<Element>

    init(_ value: Set<Element>) {
        self._value = value
    }

    var value: Set<Element> {
        get { return _value }
        set { self.apply(SetChange(removed: _value, inserted: newValue)) }
    }

    func add<Sink: SinkType>(_ sink: Sink) where Sink.Value == Update<Change> {
        signal.add(sink)
    }

    @discardableResult
    func remove<Sink: SinkType>(_ sink: Sink) -> Sink where Sink.Value == Update<Change> {
        return signal.remove(sink)
    }

    func withTransaction<Result>(_ body: () -> Result) -> Result {
        beginTransaction()
        defer { endTransaction() }
        return body()
    }

    func apply(_ update: Update<Change>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            _value.subtract(change.removed)
            _value.formUnion(change.inserted)
            sendChange(change)
        case .endTransaction:
            endTransaction()
        }
    }
}


private func describe(_ update: ValueUpdate<Set<Int>>) -> String {
    switch update {
    case .beginTransaction:
        return "begin"
    case .change(let change):
        let old = change.old.sorted()
        let new = change.new.sorted()
        return "\(old) -> \(new)"
    case .endTransaction:
        return "end"
    }
}

func checkObservableSet<T, S: ObservableSetType>(isBuffered: Bool = false, make: (Set<S.Element>) -> T, convert: (T) -> S, apply: @escaping (T, SetChange<S.Element>) -> Void) where S.Element == Int {
    let t = make([1, 2, 3])
    let test = convert(t)
    XCTAssertEqual(test.value, [1, 2, 3])
    XCTAssertEqual(test.isBuffered, isBuffered)
    XCTAssertEqual(test.count, 3)
    XCTAssertFalse(test.isEmpty)
    XCTAssertTrue(test.contains(2))
    XCTAssertFalse(test.contains(4))
    XCTAssertTrue(test.isSubset(of: [1, 2, 3, 4]))
    XCTAssertFalse(test.isSubset(of: [1, 3, 4]))
    XCTAssertTrue(test.isSuperset(of: [1, 2]))
    XCTAssertFalse(test.isSuperset(of: [0, 1]))

    let observableValue = test.anyObservableValue
    let observableCount = test.observableCount

    XCTAssertEqual(observableValue.value, [1, 2, 3])
    XCTAssertEqual(observableCount.value, 3)

    let mock = MockSetObserver(test)
    let vmock = TransformedMockSink<ValueUpdate<Set<Int>>, String>(observableValue.updates, { describe($0) })
    let cmock = MockValueUpdateSink(observableCount)

    mock.expecting(["begin", "[]/[4]", "end"]) {
        vmock.expecting(["begin", "[1, 2, 3] -> [1, 2, 3, 4]", "end"]) {
            cmock.expecting(["begin", "3 -> 4", "end"]) {
                apply(t, SetChange<Int>(inserted: [4]))
            }
        }
    }
    XCTAssertTrue(test.contains(4))
    XCTAssertEqual(test.value, [1, 2, 3, 4])

    mock.expectingNothing {
        vmock.expectingNothing {
            cmock.expectingNothing {
                apply(t, SetChange<Int>())
            }
        }
    }
    XCTAssertEqual(test.value, [1, 2, 3, 4])
}

func checkUpdatableSet<U: UpdatableSetType>(_ make: (Set<Int>) -> U) where U.Element == Int {
    do {
        let test = make([1, 2, 3])

        XCTAssertEqual(test.value, [1, 2, 3])

        let mock = MockSetObserver(test)

        mock.expecting(["begin", "[]/[4]", "end"]) {
            test.insert(4)
        }
        XCTAssertEqual(test.value, [1, 2, 3, 4])

        mock.expectingNothing {
            test.insert(2)
        }
        XCTAssertEqual(test.value, [1, 2, 3, 4])

        mock.expecting(["begin", "[2]/[]", "end"]) {
            test.remove(2)
        }
        XCTAssertEqual(test.value, [1, 3, 4])

        mock.expectingNothing {
            test.remove(2)
        }

        mock.expecting(["begin", "[]/[0]", "[3]/[]", "end"]) {
            test.withTransaction {
                test.insert(0)
                test.remove(3)
            }
        }
        XCTAssertEqual(test.value, [0, 1, 4])

        mock.expecting(["begin", "[0, 1, 4]/[10, 20, 30]", "end"]) {
            test.value = [10, 20, 30]
        }
        XCTAssertEqual(test.value, [10, 20, 30])

        mock.expecting(["begin", "[10, 20, 30]/[]", "end"]) {
            test.removeAll()
        }
        XCTAssertEqual(test.value, [])
        mock.expectingNothing {
            test.removeAll()
        }
        XCTAssertEqual(test.value, [])

        mock.expecting(["begin", "[]/[1, 2, 3]", "end"]) {
            test.formUnion([1, 2, 3])
        }
        XCTAssertEqual(test.value, [1, 2, 3])
        mock.expecting(["begin", "[3]/[]", "end"]) {
            test.formIntersection([0, 1, 2, 6])
        }
        XCTAssertEqual(test.value, [1, 2])
        mock.expecting(["begin", "[2]/[3, 4]", "end"]) {
            test.formSymmetricDifference([2, 3, 4])
        }
        XCTAssertEqual(test.value, [1, 3, 4])
        mock.expecting(["begin", "[1, 4]/[]", "end"]) {
            test.subtract([1, 4, 5])
        }
        XCTAssertEqual(test.value, [3])

        let v = test.anyUpdatableValue
        XCTAssertEqual(v.value, [3])

        mock.expecting(["begin", "[]/[1, 2]", "end"]) {
            v.value = [1, 2, 3]
        }
    }

    // Try again with no observers.
    do {
        let test = make([1, 2, 3])

        XCTAssertEqual(test.value, [1, 2, 3])

        test.insert(4)
        XCTAssertEqual(test.value, [1, 2, 3, 4])
        test.insert(2)
        XCTAssertEqual(test.value, [1, 2, 3, 4])
        test.remove(2)
        XCTAssertEqual(test.value, [1, 3, 4])
        test.remove(2)
        test.withTransaction {
            test.insert(0)
            test.remove(3)
        }
        XCTAssertEqual(test.value, [0, 1, 4])
        test.value = [10, 20, 30]
        XCTAssertEqual(test.value, [10, 20, 30])
        test.removeAll()
        XCTAssertEqual(test.value, [])
        test.removeAll()
        XCTAssertEqual(test.value, [])
        test.formUnion([1, 2, 3])
        XCTAssertEqual(test.value, [1, 2, 3])
        test.formIntersection([0, 1, 2, 6])
        XCTAssertEqual(test.value, [1, 2])
        test.formSymmetricDifference([2, 3, 4])
        XCTAssertEqual(test.value, [1, 3, 4])
        test.subtract([1, 4, 5])
        XCTAssertEqual(test.value, [3])
    }
}


class ObservableSetTypeTests: XCTestCase {
    func testDefaultImplementations() {
        checkObservableSet(make: { TestObservableSet($0) }, convert: { $0 }, apply: { $0.apply($1) })
        checkObservableSet(make: { TestObservableSet($0) }, convert: { $0.anyObservableSet }, apply: { $0.apply($1) })

        checkObservableSet(make: { TestObservableSet2($0) }, convert: { $0 }, apply: { $0.apply($1) })
        checkObservableSet(make: { TestObservableSet2($0) }, convert: { $0.anyObservableSet }, apply: { $0.apply($1) })

        checkObservableSet(make: { TestUpdatableSet($0) }, convert: { $0 }, apply: { $0.apply($1) })
        checkObservableSet(make: { TestUpdatableSet($0) }, convert: { $0.anyUpdatableSet }, apply: { $0.apply($1) })
        checkObservableSet(make: { TestUpdatableSet($0) }, convert: { $0.anyObservableSet }, apply: { $0.apply($1) })
        checkObservableSet(make: { TestUpdatableSet($0) }, convert: { $0.anyUpdatableSet.anyObservableSet }, apply: { $0.apply($1) })

        checkObservableSet(make: { TestUpdatableSet2($0) }, convert: { $0 }, apply: { $0.apply($1) })
        checkObservableSet(make: { TestUpdatableSet2($0) }, convert: { $0.anyUpdatableSet }, apply: { $0.apply($1) })
        checkObservableSet(make: { TestUpdatableSet2($0) }, convert: { $0.anyObservableSet }, apply: { $0.apply($1) })
        checkObservableSet(make: { TestUpdatableSet2($0) }, convert: { $0.anyUpdatableSet.anyObservableSet }, apply: { $0.apply($1) })

        checkObservableSet(isBuffered: true, make: { SetVariable<Int>($0) }, convert: { $0 }, apply: { $0.apply($1) })

        class T {
            let foo: TestUpdatableSet<Int>
            init(_ v: Set<Int>) { self.foo = .init(v) }
        }
        checkObservableSet(make: { Variable<T>(T($0)).map { $0.foo } }, convert: { $0 }, apply: { $0.apply($1) })

    }

    func testObservableSetConstant() {
        let constant = AnyObservableSet.constant([1, 2, 3])

        XCTAssertTrue(constant.isBuffered)
        XCTAssertEqual(constant.count, 3)
        XCTAssertEqual(constant.value, [1, 2, 3])
        XCTAssertTrue(constant.contains(2))
        XCTAssertFalse(constant.contains(0))
        XCTAssertTrue(constant.isSubset(of: [1, 2, 3, 4]))
        XCTAssertFalse(constant.isSubset(of: [1, 3, 4]))
        XCTAssertTrue(constant.isSuperset(of: [1, 2]))
        XCTAssertFalse(constant.isSuperset(of: [0, 2]))

        let mock = MockSetObserver(constant)
        mock.expectingNothing {
            // Well whatever
        }

        let observable = constant.anyObservableValue
        XCTAssertEqual(observable.value, [1, 2, 3])

        let observableCount = constant.observableCount
        XCTAssertEqual(observableCount.value, 3)
    }

    func testUpdatableDefaultImplementations() {
        checkUpdatableSet { TestUpdatableSet<Int>($0) }
        checkUpdatableSet { TestUpdatableSet<Int>($0).anyUpdatableSet }
        checkUpdatableSet { TestUpdatableSet<Int>($0).anyUpdatableSet.anyUpdatableSet }
        checkUpdatableSet { TestUpdatableSet2<Int>($0) }
        checkUpdatableSet { TestUpdatableSet2<Int>($0).anyUpdatableSet }
        checkUpdatableSet { TestUpdatableSet2<Int>($0).anyUpdatableSet.anyUpdatableSet }
        checkUpdatableSet { SetVariable<Int>($0) }
        checkUpdatableSet { SetVariable<Int>($0).anyUpdatableSet }

        class T {
            let foo: TestUpdatableSet<Int>
            init(_ v: Set<Int>) { self.foo = .init(v) }
        }
        checkUpdatableSet { Variable<T>(T($0)).map { $0.foo } }
    }

    func testObservableContains() {
        let test = SetVariable<Int>([1, 2, 3])
        let containsTwo = test.observableContains(2)

        XCTAssertEqual(containsTwo.value, true)

        let mock = MockValueUpdateSink(containsTwo)

        mock.expecting(["begin", "end", "begin", "end"]) {
            test.insert(5)
            test.remove(1)
        }
        XCTAssertEqual(containsTwo.value, true)

        mock.expecting(["begin", "true -> false", "end"]) {
            test.remove(2)
        }
        XCTAssertEqual(containsTwo.value, false)

        mock.expecting(["begin", "false -> true", "end"]) {
            test.formUnion([2, 6])
        }
        XCTAssertEqual(containsTwo.value, true)
    }
}

