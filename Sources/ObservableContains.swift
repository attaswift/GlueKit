//
//  ObservableContains.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-02.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

import Foundation

extension ObservableSetType {
    public func observableContains(_ member: Element) -> Observable<Bool> {
        return Observable(
            getter: { self.contains(member) },
            futureValues: { () -> Source<Bool> in
                self.changes
                    .filter { $0.inserted.contains(member) || $0.removed.contains(member) }
                    .map { $0.inserted.contains(member) }
            }
        )
    }
}
