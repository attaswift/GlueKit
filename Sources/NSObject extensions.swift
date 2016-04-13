//
//  NSObject extensions.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-04-11.
//  Copyright © 2016 Károly Lőrentey. All rights reserved.
//

import Foundation

private var associatedObjectKey: UInt8 = 0

public protocol ConnectorHolder: class {
    var connector: Connector { get }
}

extension ConnectorHolder {
    public var connector: Connector {
        if let connector = objc_getAssociatedObject(self, &associatedObjectKey) as? Connector {
            return connector
        }
        let connector = Connector()
        objc_setAssociatedObject(self, &associatedObjectKey, connector, .OBJC_ASSOCIATION_RETAIN)
        return connector
    }
}


extension NSObject: ConnectorHolder {
}
