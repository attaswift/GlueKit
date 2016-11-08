//
//  ConnectorTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-10.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import XCTest
@testable import GlueKit

class ConnectorTests: XCTestCase {
    
    func test_EmptyConnector() {
        let connector = Connector()
        connector.disconnect()
    }

    func test_ReleasingTheConnectorDisconnectsItsConnections() {
        var actual: [ConnectionID] = []
        var expected: [ConnectionID] = []

        do {
            let connector = Connector()
            let c = Connection { id in actual.append(id) }
            c.putInto(connector)

            XCTAssertEqual(actual, expected)

            expected.append(c.connectionID)
        }
        XCTAssertEqual(actual, expected)
    }

    func test_DisconnectingTheConnectorDisconnectsItsConnections() {
        var actual: [ConnectionID] = []
        var expected: [ConnectionID] = []

        let connector = Connector()
        let c = Connection { id in actual.append(id) }
        c.putInto(connector)
        XCTAssertEqual(actual, expected)
        expected.append(c.connectionID)
        connector.disconnect()
        XCTAssertEqual(actual, expected)

        withExtendedLifetime(connector) {}
    }

    func test_ConnectorsCanBeRestarted() {
        var actual: [ConnectionID] = []
        var expected: [ConnectionID] = []

        let connector = Connector()
        let c1 = Connection { id in actual.append(id) }
        c1.putInto(connector)
        XCTAssertEqual(actual, expected)
        expected.append(c1.connectionID)
        connector.disconnect()
        XCTAssertEqual(actual, expected)

        let c2 = Connection { id in actual.append(id) }
        c2.putInto(connector)
        XCTAssertEqual(actual, expected)
        expected.append(c2.connectionID)
        connector.disconnect()
        XCTAssertEqual(actual, expected)

        withExtendedLifetime(connector) {}
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

    func test_ConnectingASourceToASink() {
        let signal = Signal<Int>()
        let connector = Connector()
        let variable = IntVariable(0)

        connector.connect(signal, to: variable)

        XCTAssertEqual(variable.value, 0)
        signal.send(42)
        XCTAssertEqual(variable.value, 42)
        connector.disconnect()
        signal.send(23)
        XCTAssertEqual(variable.value, 42)
        withExtendedLifetime(connector) {}
    }

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

    func test_ConnectingAnObservableToAChangeSink() {
        let variable = Variable<Int>(0)
        let connector = Connector()

        var expected: [ValueChange<Int>] = []
        var actual: [ValueChange<Int>] = []

        connector.connect(variable, to: Sink({ change in actual.append(change) }))

        XCTAssertTrue(actual.elementsEqual(expected, by: ==))

        expected.append(.init(from: 0, to: 42))
        variable.value = 42

        XCTAssertTrue(actual.elementsEqual(expected, by: ==))

        connector.disconnect()
        variable.value = 23

        XCTAssertTrue(actual.elementsEqual(expected, by: ==))
        
        withExtendedLifetime(connector) {}
    }

    func test_Bind() {
        let source = Variable<Int>(0)
        let target = Variable<Int>(1)

        let connector = Connector()

        XCTAssertEqual(source.value, 0)
        XCTAssertEqual(target.value, 1)

        connector.bind(source, to: target) { $0 == $1 }
        XCTAssertEqual(source.value, 0)
        XCTAssertEqual(target.value, 0)

        source.value = 2
        XCTAssertEqual(source.value, 2)
        XCTAssertEqual(target.value, 2)

        connector.disconnect()

        source.value = 3
        XCTAssertEqual(source.value, 3)
        XCTAssertEqual(target.value, 2)

        withExtendedLifetime(connector) {}
    }

    func test_Bind_DefaultEqualityTest() {
        let source = Variable<Int>(0)
        let target = Variable<Int>(1)

        let connector = Connector()

        XCTAssertEqual(source.value, 0)
        XCTAssertEqual(target.value, 1)

        connector.bind(source, to: target)
        XCTAssertEqual(source.value, 0)
        XCTAssertEqual(target.value, 0)

        source.value = 2
        XCTAssertEqual(source.value, 2)
        XCTAssertEqual(target.value, 2)

        connector.disconnect()

        source.value = 3
        XCTAssertEqual(source.value, 3)
        XCTAssertEqual(target.value, 2)

        withExtendedLifetime(connector) {}
    }
}
