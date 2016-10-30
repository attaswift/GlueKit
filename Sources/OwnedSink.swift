//
//  StrongMethodSink.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-24.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

protocol UniqueOwnedSink: SinkType {
    associatedtype Owner: AnyObject

    var owner: Owner { get }
}

extension UniqueOwnedSink {
    var hashValue: Int {
        return ObjectIdentifier(owner).hashValue
    }

    static func ==(left: Self, right: Self) -> Bool {
        return left.owner === right.owner
    }
}

protocol OwnedSink: SinkType {
    associatedtype Owner: AnyObject
    associatedtype Identifier: Hashable

    var owner: Owner { get }
    var identifier: Identifier { get }
}

extension OwnedSink {
    var hashValue: Int {
        return Int.baseHash.mixed(with: ObjectIdentifier(owner)).mixed(with: identifier)
    }

    static func ==(left: Self, right: Self) -> Bool {
        return left.owner === right.owner && left.identifier == right.identifier
    }
}
