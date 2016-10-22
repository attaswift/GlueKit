//
//  Reference.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-13.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

internal struct UnownedReference<Target: AnyObject>: Hashable, Equatable {
    unowned var value: Target

    init(_ value: Target) {
        self.value = value
    }

    var hashValue: Int {
        return ObjectIdentifier(value).hashValue
    }

    static func ==<Target: AnyObject>(a: UnownedReference<Target>, b: UnownedReference<Target>) -> Bool {
        return a.value === b.value
    }
}


