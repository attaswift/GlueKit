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

public protocol MethodSink: SinkType {
    associatedtype Owner: AnyObject
    associatedtype Identifier: Hashable

    var owner: Owner { get }
    var identifier: Identifier { get }
}

extension MethodSink {
    public var hashValue: Int {
        return ObjectIdentifier(owner).hashValue
    }

    public static func ==(left: Self, right: Self) -> Bool {
        return left.owner === right.owner
    }
}

public struct StrongMethodSink<Owner: AnyObject, Identifier: Hashable, Value>: SinkType {
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

    public static func ==(left: StrongMethodSink, right: StrongMethodSink) -> Bool {
        return left.owner === right.owner && left.identifier == right.identifier
    }
}

public struct StrongMethodSinkWithContext<Owner: AnyObject, Context: Hashable, Value>: SinkType {
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

    public static func ==(left: StrongMethodSinkWithContext, right: StrongMethodSinkWithContext) -> Bool {
        return left.owner === right.owner && left.context == right.context
    }
}
