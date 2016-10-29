//
//  MockUpdateSink.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-09.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import XCTest
import GlueKit

internal func describe<Change: ChangeType>(_ update: Update<Change>?) -> String {
    guard let update = update else { return "nil" }
    switch update {
    case .beginTransaction: return "begin"
    case .change(let change): return "\(change)"
    case .endTransaction: return "end"
    }
}

class MockUpdateSink<Change: ChangeType>: TransformedMockSink<Update<Change>, String> {
    init() {
        super.init({ describe($0) })
    }

    init<Source: SourceType>(_ source: Source) where Source.Value == Update<Change> {
        super.init(source, { describe($0) })
    }

    convenience init<Observable: ObservableValueType>(_ observable: Observable) where Observable.Change == Change {
        self.init(observable.updates)
    }
}

typealias MockValueUpdateSink<Value> = MockUpdateSink<ValueChange<Value>>

