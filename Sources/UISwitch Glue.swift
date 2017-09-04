//
//  UISwitch Glue.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-11-12.
//  Copyright © 2015–2017 Károly Lőrentey.
//

#if os(iOS)
import UIKit

extension UISwitch {
    open override var glue: GlueForUISwitch {
        return _glue()
    }
}

open class GlueForUISwitch: GlueForUIControl {
    private var object: UISwitch { return owner as! UISwitch }

    public lazy var isOn: ComputedUpdatable<Bool>
        = ComputedUpdatable(getter: { [unowned self] in self.object.isOn },
                            setter: { [unowned self] in self.object.isOn = $0 },
                            refreshSource: self.source(for: .valueChanged).mapToVoid())
}

#endif
