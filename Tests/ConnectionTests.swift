//
//  ConnectionTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-01.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
@testable import GlueKit

class ConnectionTests: XCTestCase {

    //MARK: Callback tests

    func testConnectionCallsDisconnectCallbackOnce() {
        let c = Connection()
        var count = 0
        c.addCallback { id in count++ }

        c.disconnect()
        XCTAssertEqual(count, 1)
    }

    func testConnectionCallsDisconnectCallbackWithItsOwnIdentifier() {
        let c = Connection()
        var r = [ObjectIdentifier]()
        c.addCallback { id in r.append(id) }

        XCTAssertEqual(r, [])

        c.disconnect()

        XCTAssertEqual(r, [ObjectIdentifier(c)])
    }

    func testConnectionCallsMultipleCallbacks() {
        let c = Connection()

        var count1 = 0
        c.addCallback { id in count1++ }

        var count2 = 0
        c.addCallback { id in count2++ }

        XCTAssertEqual(count1, 0)
        XCTAssertEqual(count2, 0)

        c.disconnect()

        XCTAssertEqual(count1, 1)
        XCTAssertEqual(count2, 1)
    }

    func testDisconnectIsIdempotent() {
        let c = Connection()
        var r = [ObjectIdentifier]()
        c.addCallback { id in r.append(id) }

        XCTAssertEqual(r, [])

        c.disconnect()

        XCTAssertEqual(r, [ObjectIdentifier(c)])

        c.disconnect()

        XCTAssertEqual(r, [ObjectIdentifier(c)], "Second disconnect should be a noop")
    }

    func testAddingCallbacksAfterDisconnect() {
        let c = Connection()
        var count = 0
        c.disconnect()

        c.addCallback { id in count++ }

        XCTAssertEqual(count, 1, "New callback on disconnected connection should be immediately executed")
    }

    func testAddingCallbacksWhileDisconnecting() {
        let c = Connection()
        var outerCount = 0
        var innerCount = 0

        // This is a pathological case, but Connection should handle this correctly.
        c.addCallback { id in
            outerCount++
            // When this callback is called, the connection is already considered disconnected.
            // Thefore, addCallback should call the inner callback synchronously.
            c.addCallback { id in innerCount++ }
        }

        c.disconnect()

        XCTAssertEqual(outerCount, 1)
        XCTAssertEqual(innerCount, 1)
    }

    //MARK: Disconnect source tests

    func testDisconnectSourceFiresWhenConnectionIsDisconnected() {
        let signal = Signal<Int>()
        let targetConnection = signal.connect { i in /* Do nothing */ }

        var count = 0
        let connection = targetConnection.disconnectSource.connect { count++ }

        signal.send(1)
        signal.send(2)

        XCTAssertEqual(count, 0)

        targetConnection.disconnect()

        XCTAssertEqual(count, 1)

        connection.disconnect()
    }

    func testDisconnectSourceHasDisconnectableConnections() {
        let signal = Signal<Int>()
        let targetConnection = signal.connect { i in /* Do nothing */ }

        var count = 0
        let connection = targetConnection.disconnectSource.connect { count++ }

        signal.send(1)
        signal.send(2)

        connection.disconnect()

        XCTAssertEqual(count, 0)

        targetConnection.disconnect()

        XCTAssertEqual(count, 0)
    }

    func testDisconnectSourceDoesntRetainTheConnection() {
        var count = 0
        var connection: Connection? = nil
        do {
            let signal = Signal<Int>()
            let targetConnection = signal.connect { i in /* Do nothing */ }

            connection = targetConnection.disconnectSource.connect { count++ }

            signal.send(1)
            signal.send(2)
        } // target should deinit and disconnect here, even though connection is still alive.

        XCTAssertEqual(count, 1)
        connection?.disconnect()
    }

    func testDisconnectSourceFiresImmediatelyIfConnectionIsAlreadyDisconnected() {
        let signal = Signal<Int>()
        let targetConnection = signal.connect { i in /* Do nothing */ }

        targetConnection.disconnect()

        var count = 0
        let connection = targetConnection.disconnectSource.connect { count++ }

        XCTAssertEqual(count, 1)

        connection.disconnect()
    }

}
