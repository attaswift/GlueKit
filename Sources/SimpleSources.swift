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
    public static func empty() -> Source<SourceValue> {
        return Source { _ in return Connection() }
    }

    /// Returns a source that fires exactly once with the given value, then never again.
    public static func just(_ value: SourceValue) -> Source<SourceValue> {
        return Source { sink in
            sink.receive(value)
            return Connection()
        }
    }
}
