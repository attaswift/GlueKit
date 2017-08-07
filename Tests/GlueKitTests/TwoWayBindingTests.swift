//
//  UpdatableTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-07.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import XCTest
import GlueKit

class UpdatableTests: XCTestCase {

    func test_bind_OneWayBinding() {
        let master = Variable<Int>(0)
        let slave = Variable<Int>(100)

        let c = master.subscribe(to: slave)

        XCTAssertEqual(slave.value, 0)

        master.value = 1

        XCTAssertEqual(master.value, 1)
        XCTAssertEqual(slave.value, 1)

        slave.value = 200

        XCTAssertEqual(master.value, 1, "Connection should not be a two-way binding")
        XCTAssertEqual(slave.value, 200)

        master.value = 2

        XCTAssertEqual(master.value, 2)
        XCTAssertEqual(slave.value, 2)

        c.disconnect()

        master.value = 3

        XCTAssertEqual(master.value, 3)
        XCTAssertEqual(slave.value, 2)
    }

    func test_bind_TwoWayBinding() {
        let master = Variable<Int>(0)
        let slave = Variable<Int>(1)

        let c = master.bind(to: slave)

        XCTAssertEqual(master.value, 0) // Slave should get the value of master
        XCTAssertEqual(slave.value, 0)

        master.value = 1

        XCTAssertEqual(master.value, 1)
        XCTAssertEqual(slave.value, 1)

        slave.value = 2

        XCTAssertEqual(master.value, 2)
        XCTAssertEqual(slave.value, 2)

        c.disconnect() // The variables should now be independent again.

        master.value = 3

        XCTAssertEqual(master.value, 3)
        XCTAssertEqual(slave.value, 2)
        
        slave.value = 4
        
        XCTAssertEqual(master.value, 3)
        XCTAssertEqual(slave.value, 4)
    }

    func test_Connector_bind() {
        let master = Variable<Int>(0)
        let slave = Variable<Int>(1)

        let connector = Connector()
        connector.bind(master, to: slave)

        XCTAssertEqual(master.value, 0) // Slave should get the value of master
        XCTAssertEqual(slave.value, 0)

        master.value = 1

        XCTAssertEqual(master.value, 1)
        XCTAssertEqual(slave.value, 1)

        slave.value = 2

        XCTAssertEqual(master.value, 2)
        XCTAssertEqual(slave.value, 2)

        connector.disconnect() // The variables should now be independent again.

        master.value = 3

        XCTAssertEqual(master.value, 3)
        XCTAssertEqual(slave.value, 2)

        slave.value = 4

        XCTAssertEqual(master.value, 3)
        XCTAssertEqual(slave.value, 4)
    }

    func test_updates_masterTransaction() {
        let master = Variable<Int>(0)
        let slave = Variable<Int>(1)

        let msink = MockValueUpdateSink<Int>(master)
        let ssink = MockValueUpdateSink<Int>(slave)

        let c = msink.expecting(["begin", "end"]) {
            ssink.expecting(["begin", "1 -> 0", "end"]) {
                return master.bind(to: slave)
            }
        }

        msink.expecting("begin") {
            ssink.expecting("begin") {
                master.apply(.beginTransaction)
            }
        }

        msink.expecting("0 -> 2") {
            ssink.expecting("0 -> 2") {
                master.value = 2
            }
        }

        msink.expecting("end") {
            ssink.expecting("end") {
                master.apply(.endTransaction)
            }
        }

        msink.expectingNothing {
            ssink.expectingNothing {
                c.disconnect()
            }
        }

        ssink.disconnect()
        msink.disconnect()
    }

    func test_updates_slaveTransaction() {
        let master = Variable<Int>(0)
        let slave = Variable<Int>(1)

        let msink = MockValueUpdateSink<Int>(master)
        let ssink = MockValueUpdateSink<Int>(slave)

        let c = msink.expecting(["begin", "end"]) {
            ssink.expecting(["begin", "1 -> 0", "end"]) {
                return master.bind(to: slave)
            }
        }

        msink.expecting("begin") {
            ssink.expecting("begin") {
                slave.apply(.beginTransaction)
            }
        }

        msink.expecting("0 -> 2") {
            ssink.expecting("0 -> 2") {
                slave.value = 2
            }
        }

        msink.expecting("end") {
            ssink.expecting("end") {
                slave.apply(.endTransaction)
            }
        }

        msink.expectingNothing {
            ssink.expectingNothing {
                c.disconnect()
            }
        }
        
        ssink.disconnect()
        msink.disconnect()
    }

    #if false // Binding/unbinding during transactions is currently unsupported.
    func test_updates_bindingDuringMasterTransaction() {
        let master = Variable<Int>(0)
        let slave = Variable<Int>(1)

        let sink = MockValueUpdateSink<Int>(slave)

        master.apply(.beginTransaction)

        let c = sink.expecting(["begin", "1 -> 0"]) {
            return master.bind(to: slave)
        }

        sink.expecting("0 -> 2") {
            master.value = 2
        }

        sink.expecting("end") {
            master.apply(.endTransaction)
        }

        sink.expectingNothing {
            c.disconnect()
        }
        
        sink.disconnect()
    }

    func test_updates_bindingDuringSinkTransaction() {
        let master = Variable<Int>(0)
        let slave = Variable<Int>(1)

        let sink = MockValueUpdateSink<Int>(slave)

        sink.expecting("begin") {
            slave.apply(.beginTransaction)
        }

        let c = sink.expecting(["1 -> 0"]) {
            return master.bind(to: slave)
        }

        sink.expecting("0 -> 2") {
            master.value = 2
        }

        sink.expectingNothing {
            master.apply(.endTransaction)
        }

        sink.expectingNothing {
            c.disconnect()
        }

        sink.expecting("end") {
            slave.apply(.endTransaction)
        }
        
        sink.disconnect()
    }

    func test_updates_unbindingDuringMasterTransaction() {
        let master = Variable<Int>(0)
        let slave = Variable<Int>(1)

        let sink = MockValueUpdateSink<Int>(slave)

        let c = sink.expecting(["begin", "0 -> 1", "end"]) {
            return master.bind(to: slave)
        }

        sink.expecting("begin") {
            master.apply(.beginTransaction)
        }

        sink.expecting("1 -> 2") {
            master.value = 2
        }

        sink.expecting("end") {
            c.disconnect()
        }

        sink.expectingNothing {
            master.apply(.endTransaction)
        }
        
        sink.disconnect()
    }

    func test_updates_unbindingDuringSinkTransaction() {
        let master = Variable<Int>(0)
        let slave = Variable<Int>(1)

        let sink = MockValueUpdateSink<Int>(slave)

        let c = sink.expecting(["begin", "0 -> 1", "end"]) {
            return master.bind(to: slave)
        }

        sink.expecting("begin") {
            slave.apply(.beginTransaction)
        }

        sink.expecting("1 -> 2") {
            master.value = 2
        }

        sink.expectingNothing {
            c.disconnect()
        }

        sink.expectingNothing {
            master.apply(.endTransaction)
        }

        sink.expecting("end") {
            slave.apply(.endTransaction)
        }
        
        sink.disconnect()
    }
    #endif
}
