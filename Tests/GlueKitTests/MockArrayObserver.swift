//
//  MockArrayObserver.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-06.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import Foundation
import XCTest
import GlueKit

internal func describe<Element>(_ update: Update<ArrayChange<Element>>?) -> String {
    guard let update = update else { return "nil" }
    switch update {
    case .beginTransaction:
        return "begin"
    case .change(let change):
        let mods = change.modifications.map { mod in "\(mod)" }
        return "\(change.initialCount)\(mods.joined())"
    case .endTransaction:
        return "end"
    }
}

class MockArrayObserver<Element>: MockSinkProtocol {
    typealias Change = ArrayChange<Element>

    let state: MockSinkState<Update<Change>, String>

    init() {
        state = .init({ describe($0) })
    }

    init<Source: SourceType>(_ source: Source) where Source.Value == Update<Change> {
        state = .init({ describe($0) })
        self.subscribe(to: source)
    }

    convenience init<Observable: ObservableArrayType>(_ observable: Observable) where Observable.Change == Change {
        self.init(observable.updates)
    }

    func receive(_ value: Update<Change>) {
        state.receive(value)
    }
}
