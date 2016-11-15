//
//  StrongMethodSink.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-24.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import SipHash

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

protocol OwnedSink: SinkType, SipHashable {
    associatedtype Owner: AnyObject
    associatedtype Identifier: Hashable

    var owner: Owner { get }
    var identifier: Identifier { get }
}

extension OwnedSink {
    func appendHashes(to hasher: inout SipHasher) {
        hasher.append(ObjectIdentifier(owner))
        hasher.append(identifier)
    }

    static func ==(left: Self, right: Self) -> Bool {
        return left.owner === right.owner && left.identifier == right.identifier
    }
}
