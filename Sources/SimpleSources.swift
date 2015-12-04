//
//  SimpleSources.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-11-30.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import Foundation

extension SourceType {
    /// Returns a source that never fires.
    public static func emptySource() -> Source<Value> {
        return Source { _ in return Connection() }
    }

    /// Returns a source that fires exactly once with the given value, then never again.
    public static func constantSource(value: Value) -> Source<Value> {
        return Source { sink in
            sink(value)
            return Connection()
        }
    }
}
