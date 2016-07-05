//
//  NSUserDefaults Support.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-04-11.
//  Copyright © 2016 Károly Lőrentey. All rights reserved.
//

import Foundation

extension UserDefaults {
    public func updatable(for key: String) -> Updatable<AnyObject?> {
        let defaults = UserDefaults.standard()
        return Updatable(
            observable: defaults.observableForKeyPath(key).distinct { a, b in a?.isEqual(b) == true },
            setter: { defaults.set($0, forKey: key) })
    }

    public func updatableBool(for key: String, defaultValue: Bool = false) -> Updatable<Bool> {
        let defaults = UserDefaults.standard()
        return Updatable(
            observable: defaults.observableForKeyPath(key).map { value in
                guard let object = value else { return defaultValue }
                return object.boolValue
            },
            setter: { value in
                defaults.set(value, forKey: key)
        })
    }

    public func updatableInt(for key: String, defaultValue: Int = 0) -> Updatable<Int> {
        let defaults = UserDefaults.standard()
        return Updatable(
            observable: defaults.observableForKeyPath(key).map { value in
                guard let object = value else { return defaultValue }
                return object.intValue
            },
            setter: { value in
                defaults.set(value, forKey: key)
        })
    }

    public func updatableDouble(for key: String, defaultValue: Double = 0) -> Updatable<Double> {
        let defaults = UserDefaults.standard()
        return Updatable(
            observable: defaults.observableForKeyPath(key).map { value in
                guard let object = value else { return defaultValue }
                return object.doubleValue
            },
            setter: { value in
                defaults.set(value, forKey: key)
        })
    }

    public func updatableString(for key: String, defaultValue: String? = nil) -> Updatable<String?> {
        let defaults = UserDefaults.standard()
        return Updatable(
            observable: defaults.observableForKeyPath(key).map { value in
                guard let string = value as? String else { return defaultValue }
                return string
            },
            setter: { value in
                defaults.set(value, forKey: key)
        })
    }
}
