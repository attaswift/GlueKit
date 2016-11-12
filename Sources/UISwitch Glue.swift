//
//  UISwitch Glue.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-11-12.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

#if os(iOS)
import UIKit

extension UISwitch {
    public override var glue: GlueForUISwitch {
        return getOrCreateGlue()
    }
}

public class GlueForUISwitch: GlueForUIControl {
    private var object: UISwitch { return owner as! UISwitch }

    public lazy var isOn: ComputedUpdatable<Bool>
        = ComputedUpdatable(getter: { [unowned self] in self.object.isOn },
                            setter: { [unowned self] in self.object.isOn = $0 },
                            refreshSource: self.object.glue.source(for: .valueChanged).map { _ in })
}

#endif
