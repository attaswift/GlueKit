//
//  TypeHelperTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-10.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import Foundation
import XCTest
import GlueKit

private class KVOTest: NSObject {
    @objc dynamic var string: String = ""
    @objc dynamic var bool: Bool = false
    @objc dynamic var int: Int = 0
    @objc dynamic var float: Float = 0
    @objc dynamic var double: Double = 0
    @objc dynamic var cgFloat: CGFloat = 0
    @objc dynamic var point: CGPoint = .init(x: 0, y: 0)
    @objc dynamic var size: CGSize = .init(width: 0, height: 0)
    @objc dynamic var rect: CGRect = .init(x: 0, y: 0, width: 0, height: 0)
    @objc dynamic var transform: CGAffineTransform = .identity
}

class TypeHelperTests: XCTestCase {

    private func check<V: Equatable>(
        type: V.Type = V.self,
        key: String,
        sourceTx: (AnySource<Any?>) -> AnySource<V>,
        observableTx: (AnyObservableValue<Any?>) -> AnyObservableValue<V>,
        updatableTx: (AnyUpdatableValue<Any?>) -> AnyUpdatableValue<V>,
        getter: (KVOTest) -> V,
        setter: (KVOTest, V) -> (),
        value0: V,
        value1: V,
        value2: V)
    {
        let t = KVOTest()
        setter(t, value0)

        let source = sourceTx(t.glue.observable(forKeyPath: key).futureValues)
        let observable = observableTx(t.glue.observable(forKeyPath: key))
        let updatable = updatableTx(t.glue.updatable(forKey: key))

        XCTAssertEqual(observable.value, value0)
        XCTAssertEqual(updatable.value, value0)

        let smock = MockSink(source)
        let omock = MockValueUpdateSink(observable)
        let umock = MockValueUpdateSink(updatable)

        smock.expecting(value1) {
            omock.expecting(["begin", "\(value0) -> \(value1)", "end"]) {
                umock.expecting(["begin", "\(value0) -> \(value1)", "end"]) {
                    setter(t, value1)
                }
            }
        }
        XCTAssertEqual(observable.value, value1)
        XCTAssertEqual(updatable.value, value1)

        smock.expecting(value2) {
            omock.expecting(["begin", "\(value1) -> \(value2)", "end"]) {
                umock.expecting(["begin", "\(value1) -> \(value2)", "end"]) {
                    updatable.value = value2
                }
            }
        }
        XCTAssertEqual(observable.value, value2)
        XCTAssertEqual(updatable.value, value2)
        XCTAssertEqual(getter(t), value2)
    }

    func testForceCasting() {
        check(key: "string",
              sourceTx: { $0.forceCasted(to: NSString.self) },
              observableTx: { $0.forceCasted(to: NSString.self) },
              updatableTx: { $0.forceCasted(to: NSString.self) },
              getter: { $0.string as NSString },
              setter: { $0.string = $1 as String },
              value0: "foo",
              value1: "bar",
              value2: "baz")
        check(key: "int",
              sourceTx: { $0.forceCasted(to: NSNumber.self) },
              observableTx: { $0.forceCasted(to: NSNumber.self) },
              updatableTx: { $0.forceCasted(to: NSNumber.self) },
              getter: { NSNumber(value: $0.int) },
              setter: { $0.int = $1.intValue },
              value0: NSNumber(value: 2),
              value1: NSNumber(value: 3),
              value2: NSNumber(value: 4))
    }

    func testString() {
        check(key: "string", sourceTx: { $0.asString }, observableTx: { $0.asString }, updatableTx: { $0.asString },
              getter: { $0.string },
              setter: { $0.string = $1 },
              value0: "foo",
              value1: "bar",
              value2: "baz")
    }

    func testBool() {
        check(key: "bool", sourceTx: { $0.asBool }, observableTx: { $0.asBool }, updatableTx: { $0.asBool },
              getter: { $0.bool },
              setter: { $0.bool = $1 },
              value0: false,
              value1: true,
              value2: false)
    }

    func testInt() {
        check(key: "int", sourceTx: { $0.asInt }, observableTx: { $0.asInt }, updatableTx: { $0.asInt },
              getter: { $0.int },
              setter: { $0.int = $1 },
              value0: 1,
              value1: 2,
              value2: 3)
    }

    func testFloat() {
        check(key: "float", sourceTx: { $0.asFloat }, observableTx: { $0.asFloat }, updatableTx: { $0.asFloat },
              getter: { $0.float },
              setter: { $0.float = $1 },
              value0: 1,
              value1: 2,
              value2: 3)
        check(key: "int", sourceTx: { $0.asFloat }, observableTx: { $0.asFloat }, updatableTx: { $0.asFloat },
              getter: { Float($0.int) },
              setter: { $0.int = Int($1) },
              value0: 1,
              value1: 2,
              value2: 3)
        check(key: "double", sourceTx: { $0.asFloat }, observableTx: { $0.asFloat }, updatableTx: { $0.asFloat },
              getter: { Float($0.double) },
              setter: { $0.double = Double($1) },
              value0: 1,
              value1: 2,
              value2: 3)
    }

    func testDouble() {
        check(key: "double", sourceTx: { $0.asDouble }, observableTx: { $0.asDouble }, updatableTx: { $0.asDouble },
              getter: { $0.double },
              setter: { $0.double = $1 },
              value0: 1,
              value1: 2,
              value2: 3)
        check(key: "float", sourceTx: { $0.asDouble }, observableTx: { $0.asDouble }, updatableTx: { $0.asDouble },
              getter: { Double($0.float) },
              setter: { $0.float = Float($1) },
              value0: 1,
              value1: 2,
              value2: 3)
        check(key: "int", sourceTx: { $0.asDouble }, observableTx: { $0.asDouble }, updatableTx: { $0.asDouble },
              getter: { Double($0.int) },
              setter: { $0.int = Int($1) },
              value0: 1,
              value1: 2,
              value2: 3)
    }

    func testCGFloat() {
        check(key: "cgFloat", sourceTx: { $0.asCGFloat }, observableTx: { $0.asCGFloat }, updatableTx: { $0.asCGFloat },
              getter: { $0.cgFloat },
              setter: { $0.cgFloat = $1 },
              value0: 1,
              value1: 2,
              value2: 3)
        check(key: "int", sourceTx: { $0.asCGFloat }, observableTx: { $0.asCGFloat }, updatableTx: { $0.asCGFloat },
              getter: { CGFloat($0.int) },
              setter: { $0.int = Int($1) },
              value0: 1,
              value1: 2,
              value2: 3)
        check(key: "float", sourceTx: { $0.asCGFloat }, observableTx: { $0.asCGFloat }, updatableTx: { $0.asCGFloat },
              getter: { CGFloat($0.float) },
              setter: { $0.float = Float($1) },
              value0: 1,
              value1: 2,
              value2: 3)
    }

    func testCGPoint() {
        check(key: "point", sourceTx: { $0.asCGPoint }, observableTx: { $0.asCGPoint }, updatableTx: { $0.asCGPoint },
              getter: { $0.point },
              setter: { $0.point = $1 },
              value0: CGPoint(x: 1, y: 2),
              value1: CGPoint(x: 3, y: 4),
              value2: CGPoint(x: 5, y: 6))
    }

    func testCGSize() {
        check(key: "size", sourceTx: { $0.asCGSize }, observableTx: { $0.asCGSize }, updatableTx: { $0.asCGSize },
              getter: { $0.size },
              setter: { $0.size = $1 },
              value0: CGSize(width: 1, height: 2),
              value1: CGSize(width: 3, height: 4),
              value2: CGSize(width: 5, height: 6))
    }

    func testCGRect() {
        check(key: "rect", sourceTx: { $0.asCGRect }, observableTx: { $0.asCGRect }, updatableTx: { $0.asCGRect },
              getter: { $0.rect },
              setter: { $0.rect = $1 },
              value0: CGRect(x: 1, y: 2, width: 3, height: 4),
              value1: CGRect(x: 5, y: 6, width: 7, height: 8),
              value2: CGRect(x: 9, y: 10, width: 11, height: 12))
    }

    func testCGAffineTransform() {
        check(key: "transform",
              sourceTx: { $0.asCGAffineTransform },
              observableTx: { $0.asCGAffineTransform },
              updatableTx: { $0.asCGAffineTransform },
              getter: { $0.transform },
              setter: { $0.transform = $1 },
              value0: CGAffineTransform(rotationAngle: CGFloat.pi / 4),
              value1: CGAffineTransform(scaleX: 0.4, y: 0.6),
              value2: CGAffineTransform(translationX: 100, y: 200))
    }


}
