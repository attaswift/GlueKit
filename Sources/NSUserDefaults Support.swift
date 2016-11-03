//
//  NSUserDefaults Support.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-04-11.
//  Copyright © 2016 Károly Lőrentey. All rights reserved.
//

import Foundation

extension UserDefaults {
    public func updatableBool(forKey key: String, defaultValue: Bool = false) -> AnyUpdatableValue<Bool> {
        return self.updatable(forKey: key)
            .map({ v in (v as? NSNumber)?.boolValue ?? defaultValue },
                 inverse: { v in v })
    }

    public func updatableInt(forKey key: String, defaultValue: Int = 0) -> AnyUpdatableValue<Int> {
        return self.updatable(forKey: key)
            .map({ v in (v as? NSNumber)?.intValue ?? defaultValue },
                 inverse: { v in v })
    }

    public func updatableDouble(forKey key: String, defaultValue: Double = 0) -> AnyUpdatableValue<Double> {
        return self.updatable(forKey: key)
            .map({ v in (v as? NSNumber)?.doubleValue ?? defaultValue },
                 inverse: { v in v })
    }

    public func updatableString(forKey key: String, defaultValue: String? = nil) -> AnyUpdatableValue<String?> {
        return self.updatable(forKey: key)
            .map({ v in (v as? String) ?? defaultValue },
                 inverse: { v in v })
    }
}
