//
//  Reference.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-13.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

internal struct UnownedReference<Class: AnyObject>: Hashable, Equatable {
    unowned var value: Class

    init(_ value: Class) {
        self.value = value
    }

    internal var hashValue: Int {
        return ObjectIdentifier(value).hashValue
    }
}

internal func ==<Class: AnyObject>(a: UnownedReference<Class>, b: UnownedReference<Class>) -> Bool {
    return a.value === b.value
}

