//
//  UISearchBar Glue.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2017-05-08.
//  Copyright © 2015–2017 Károly Lőrentey.
//

#if os(iOS)
import UIKit

extension UISearchBar {
    open override var glue: GlueForUISearchBar {
        return _glue()
    }
}

open class GlueForUISearchBar: GlueForNSObject, UISearchBarDelegate {
    private var object: UISearchBar { return owner as! UISearchBar }

    public lazy var text: ComputedUpdatable<String?>
        = ComputedUpdatable(
            getter: { [unowned self] in self.object.text },
            setter: { [unowned self] in self.object.text = $0 })

    private lazy var _isEditing = Variable<Bool>(false)
    public var isEditing: AnyObservableValue<Bool> { return _isEditing.anyObservableValue }

    public required init(owner: NSObject) {
        super.init(owner: owner)
        object.delegate = self
    }

    public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        text.refresh()
    }

    public func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        _isEditing.value = true
    }

    public func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        _isEditing.value = false
    }

    public func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        return true
    }
    public func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool {
        return true
    }
}

#endif
