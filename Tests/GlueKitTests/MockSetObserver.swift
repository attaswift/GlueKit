//
//  MockSetObserver.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-06.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import Foundation
import XCTest
import GlueKit

func describe<Element: Comparable>(_ update: SetUpdate<Element>) -> String {
    switch update {
    case .beginTransaction:
        return "begin"
    case .change(let change):
        let removed = change.removed.sorted().map { "\($0)" }.joined(separator: ", ")
        let inserted = change.inserted.sorted().map { "\($0)" }.joined(separator: ", ")
        return "[\(removed)]/[\(inserted)]"
    case .endTransaction:
        return "end"
    }
}

class MockSetObserver<Element: Hashable & Comparable>: MockSinkProtocol {
    typealias Change = SetChange<Element>

    let state: MockSinkState<SetUpdate<Element>, String>

    init() {
        state = .init({ describe($0) })
    }

    init<Source: SourceType>(_ source: Source) where Source.Value == Update<Change> {
        state = .init({ describe($0) })
        self.subscribe(to: source)
    }

    convenience init<Observable: ObservableSetType>(_ observable: Observable) where Observable.Change == Change {
        self.init(observable.updates)
    }

    func receive(_ value: Update<Change>) {
        state.receive(value)
    }
}
