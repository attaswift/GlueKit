//
//  ObservableTypeTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-28.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
import GlueKit

class ObservableTypeTests: XCTestCase {
    func test_UpdatableType_withTransaction() {
        let test = TestUpdatable(0)

        let sink = MockUpdateSink<TestChange>()
        test.updates.add(sink)

        sink.expecting(["begin", "end"]) {
            test.withTransaction {}
        }

        sink.expecting(["begin", "0 -> 1", "end"]) {
            test.withTransaction {
                test.apply(TestChange(from: 0, to: 1))
            }
        }

        sink.expecting(["begin", "1 -> 2", "2 -> 3", "end"]) {
            test.withTransaction {
                test.apply(TestChange(from: 1, to: 2))
                test.apply(TestChange(from: 2, to: 3))
            }
        }

        sink.expecting(["begin", "3 -> 4", "end"]) {
            test.withTransaction {
                test.withTransaction {
                    test.apply(TestChange(from: 3, to: 4))
                }
            }
        }

        test.updates.remove(sink)
    }

    func test_UpdatableType_applyChange() {
        let test = TestUpdatable(0)

        let sink = MockUpdateSink<TestChange>()
        test.updates.add(sink)

        sink.expecting(["begin", "0 -> 1", "end"]) {
            test.apply(TestChange([0, 1]))
        }

        test.updates.remove(sink)
    }

    #if false // TODO Compiler crash in Xcode 8.3.2
    func test_Connector_connectObservableToUpdateSink() {
        let observable = TestObservable(0)

        let connector = Connector()

        var received: [Update<TestChange>] = []
        connector.connect(observable) { update in received.append(update) }

        observable.value = 1
        
        XCTAssertEqual(received.map { "\($0)" }, ["beginTransaction", "change(0 -> 1)", "endTransaction"])
        received = []

        connector.disconnect()

        observable.value = 2

        XCTAssertEqual(received.map { "\($0)" }, [])
    }
    #endif

    #if false // TODO Compiler crash in Xcode 8.3.2
    func test_Connector_connectObservableToChangeSink() {
        let observable = TestObservable(0)

        let connector = Connector()

        var received: [TestChange] = []
        connector.connect(observable) { change in received.append(change) }

        observable.value = 1

        XCTAssertEqual(received.map { "\($0)" }, ["0 -> 1"])
        received = []

        connector.disconnect()

        observable.value = 2

        XCTAssertEqual(received.map { "\($0)" }, [])
    }
    #endif
}
