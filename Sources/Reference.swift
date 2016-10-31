//
//  Reference.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-13.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

internal struct UnownedReference<Target: AnyObject> {
    unowned var value: Target

    init(_ value: Target) {
        self.value = value
    }
}


