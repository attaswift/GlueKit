//
//  MockUpdateSink.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-09.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
import GlueKit

internal func describe<Change>(_ update: Update<Change>?) -> String {
    guard let update = update else { return "nil" }
    switch update {
    case .beginTransaction: return "begin"
    case .change(let change): return "\(change)"
    case .endTransaction: return "end"
    }
}

class MockUpdateSink<Change: ChangeType>: MockSinkProtocol {
    let state: MockSinkState<Update<Change>, String>

    init() {
        state = .init({ describe($0) })
    }

    init<Source: SourceType>(_ source: Source) where Source.Value == Update<Change> {
        state = .init({ describe($0) })
        self.subscribe(to: source)
    }

    convenience init<Observable: ObservableValueType>(_ observable: Observable) where Observable.Change == Change {
        self.init(observable.updates)
    }

    func receive(_ value: Update<Change>) {
        state.receive(value)
    }
}

typealias MockValueUpdateSink<Value> = MockUpdateSink<ValueChange<Value>>

