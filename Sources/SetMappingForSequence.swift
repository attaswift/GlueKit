//
//  SetMappingForSequence.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-07.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableSetType {
    public func flatMap<Result: Sequence>(_ key: @escaping (Element) -> Result) -> ObservableSet<Result.Iterator.Element> where Result.Iterator.Element: Hashable {
        return SetMappingForSequence<Self, Result>(base: self, key: key).observableSet
    }
}

class SetMappingForSequence<S: ObservableSetType, Result: Sequence>: MultiObservableSet<Result.Iterator.Element> where Result.Iterator.Element: Hashable {
    typealias Element = Result.Iterator.Element
    let base: S
    let key: (S.Element) -> Result

    var baseConnection: Connection? = nil

    init(base: S, key: @escaping (S.Element) -> Result) {
        self.base = base
        self.key = key
        super.init()
        baseConnection = base.changes.connect { [unowned self] change in self.apply(change) }

        for e in base.value {
            for new in key(e) {
                _ = self.insert(new)
            }
        }
    }

    deinit {
        baseConnection?.disconnect()
    }

    private func apply(_ change: SetChange<S.Element>) {
        var transformedChange = SetChange<Element>()
        for e in change.removed {
            for old in key(e) {
                if self.remove(old) {
                    transformedChange.remove(old)
                }
            }
        }
        for e in change.inserted {
            for new in key(e) {
                if self.insert(new) {
                    transformedChange.insert(new)
                }
            }
        }
        if !transformedChange.isEmpty {
            signal.send(transformedChange)
        }
    }
}
