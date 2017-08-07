//
//  Reference.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-13.
//  Copyright © 2015–2017 Károly Lőrentey.
//

internal struct UnownedReference<Target: AnyObject> {
    unowned var value: Target

    init(_ value: Target) {
        self.value = value
    }
}


