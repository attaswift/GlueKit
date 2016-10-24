//
//  ObservableContains.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-02.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

extension ObservableSetType {
    public func observableContains(_ member: Element) -> AnyObservableValue<Bool> {
        return ObservableContains(input: self, member: member).anyObservable
    }
}

private final class ObservableContains<Input: ObservableSetType>: _AbstractObservableValue<Bool> {
    let input: Input
    let member: Input.Element

    init(input: Input, member: Input.Element) {
        self.input = input
        self.member = member
    }

    override var value: Bool {
        return input.contains(member)
    }

    override var updates: ValueUpdateSource<Bool> {
        let member = self.member
        return input.updates.flatMap { update in
            update
                .filter { $0.inserted.contains(member) || $0.removed.contains(member) }?
                .map {
                    let contains = $0.inserted.contains(member)
                    return .init(from: !contains, to: contains)
            }
        }
    }
}
