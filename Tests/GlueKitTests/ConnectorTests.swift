//
//  ConnectorTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-10.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
@testable import GlueKit

class TestConnection: Connection {
    var callback: (() -> ())?

    init(_ callback: @escaping () -> ()) {
        self.callback = callback
        super.init()
    }

    deinit {
        disconnect()
    }

    override func disconnect() {
        guard let callback = self.callback else { return }
        self.callback = nil
        callback()
    }
}
class ConnectorTests: XCTestCase {
    
    func test_EmptyConnector() {
        let connector = Connector()
        connector.disconnect()
    }

    func test_ReleasingTheConnectorDisconnectsItsConnections() {
        var actual: [Int] = []
        do {
            let connector = Connector()
            let c = TestConnection { actual.append(1) }
            c.putInto(connector)

            XCTAssertEqual(actual, [])
        }
        XCTAssertEqual(actual, [1])
    }

    func test_DisconnectingTheConnectorDisconnectsItsConnections() {
        var actual: [Int] = []

        do {
            let connector = Connector()
            let c = TestConnection { actual.append(1) }
            c.putInto(connector)
            XCTAssertEqual(actual, [])
            connector.disconnect()
            XCTAssertEqual(actual, [1])
            withExtendedLifetime(connector) {}
        }
        XCTAssertEqual(actual, [1])
    }

    func test_ConnectorsCanBeRestarted() {
        var actual: [Int] = []

        do {
            let connector = Connector()
            let c1 = TestConnection { actual.append(1) }
            c1.putInto(connector)
            XCTAssertEqual(actual, [])
            connector.disconnect()
            XCTAssertEqual(actual, [1])

            let c2 = TestConnection { actual.append(2) }
            c2.putInto(connector)
            XCTAssertEqual(actual, [1])
            connector.disconnect()
            XCTAssertEqual(actual, [1, 2])
            
            withExtendedLifetime(connector) {}
        }
        XCTAssertEqual(actual, [1, 2])
    }

    func test_ConnectingASourceToAClosure() {
        let signal = Signal<Int>()
        let connector = Connector()

        var expected: [Int] = []
        var actual: [Int] = []
        connector.connect(signal) { value in actual.append(value) }

        XCTAssertEqual(actual, expected)

        expected.append(42)
        signal.send(42)
        XCTAssertEqual(actual, expected)

        connector.disconnect()
        signal.send(23)
        XCTAssertEqual(actual, expected)

        withExtendedLifetime(connector) {}
    }

    #if false // TODO Compiler crash in Xcode 8.3.2
    func test_ConnectingAnObservableToAChangeClosure() {
        let variable = Variable<Int>(0)
        let connector = Connector()

        var expected: [ValueChange<Int>] = []
        var actual: [ValueChange<Int>] = []

        connector.connect(variable) { change in actual.append(change) }

        XCTAssertTrue(actual.elementsEqual(expected, by: ==))

        expected.append(.init(from: 0, to: 42))
        variable.value = 42

        XCTAssertTrue(actual.elementsEqual(expected, by: ==))

        connector.disconnect()
        variable.value = 23

        XCTAssertTrue(actual.elementsEqual(expected, by: ==))

        withExtendedLifetime(connector) {}
    }
    #endif
}
