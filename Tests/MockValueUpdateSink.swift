//
//  MockValueUpdateSink.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-09.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import XCTest
import GlueKit

private func describe<Value>(_ update: ValueUpdate<Value>) -> String {
    switch update {
    case .beginTransaction: return "begin"
    case .change(let change): return "\(change.old)→\(change.new)"
    case .endTransaction: return "end"
    }
}

class MockValueUpdateSink<Value>: TransformedMockSink<ValueUpdate<Value>, String> {
    init() {
        super.init({ describe($0) })
    }

    init<Source: SourceType>(_ source: Source) where Source.Value == ValueUpdate<Value> {
        super.init(source, { describe($0) })
    }

    init<Observable: ObservableValueType>(_ observable: Observable) where Observable.Value == Value {
        super.init(observable.updates, { describe($0) })
    }

}

