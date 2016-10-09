//
//  CombinedUpdatableTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-09.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation
import XCTest
import GlueKit

private class TestObservable: ObservableValueType {
    var _signal = Signal<SimpleChange<Int>>()

    var value: Int = 0{
        didSet {
            _signal.send(.init(from: oldValue, to: value))
        }
    }

    var changes: Source<SimpleChange<Int>> { return _signal.source }
}

private class TestUpdatable: UpdatableValueType {
    var _signal = Signal<SimpleChange<Int>>()

    var value: Int = 0 {
        didSet {
            _signal.send(.init(from: oldValue, to: value))
        }
    }

    var changes: Source<SimpleChange<Int>> { return _signal.source }
}

class CombinedUpdatableTests: XCTestCase {
    func test() {
        // TODO
    }
}
