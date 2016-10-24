//
//  MethodSink.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-24.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

public struct MethodSink<Owner: AnyObject, Identifier: Hashable, Value>: SinkType {
    public let owner: Owner
    public let identifier: Identifier
    public let method: (Owner) -> (Value) -> Void

    public init(owner: Owner, identifier: Identifier, method: @escaping (Owner) -> (Value) -> Void) {
        self.owner = owner
        self.identifier = identifier
        self.method = method
    }

    public func receive(_ value: Value) {
        method(owner)(value)
    }

    public var hashValue: Int {
        return Int.baseHash.mixed(with: ObjectIdentifier(owner).hashValue).mixed(with: identifier.hashValue)
    }

    public static func ==(left: MethodSink, right: MethodSink) -> Bool {
        return left.owner === right.owner && left.identifier == right.identifier
    }
}

public struct MethodSinkWithContext<Owner: AnyObject, Context: Hashable, Value>: SinkType {
    public let owner: Owner
    public let method: (Owner) -> (Value, Context) -> Void
    public let context: Context

    public init(owner: Owner, method: @escaping (Owner) -> (Value, Context) -> Void, context: Context) {
        self.owner = owner
        self.method = method
        self.context = context
    }

    public func receive(_ value: Value) {
        method(owner)(value, context)
    }

    public var hashValue: Int {
        return Int.baseHash.mixed(with: ObjectIdentifier(owner).hashValue).mixed(with: context.hashValue)
    }

    public static func ==(left: MethodSinkWithContext, right: MethodSinkWithContext) -> Bool {
        return left.owner === right.owner && left.context == right.context
    }
}
