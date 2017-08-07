//
//  RefList.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-09-26.
//  Copyright © 2015–2017 Károly Lőrentey.
//

/// An element in a reflist, with an opaque link to its parent node.
protocol RefListElement: class {
    /// An opaque link to the element's parent node in the ref list.
    var refListLink: RefListLink<Self> { get set }
}

internal struct RefListLink<Element: RefListElement> {
    fileprivate var _parent: UnownedReference<RefListNode<Element>>?

    internal init() {
        self._parent = nil
    }
}

extension RefListElement {
    fileprivate var parent: RefListNode<Self>? {
        get {
            return refListLink._parent?.value
        }
        set {
            if let p = newValue {
                refListLink._parent = UnownedReference(p)
            }
            else {
                refListLink._parent = nil
            }
        }
    }
}

/// A reflist is a B-tree backed random-access list data structure. It does not support copy-on-write mutation,
/// but it supports parent links, allowing for efficient determination of any element's position in the list in O(log(n)) time.
/// Elements in the refList may only be in a single list at a time.
internal final class RefList<Element: RefListElement>: RandomAccessCollection, MutableCollection, RangeReplaceableCollection {
    fileprivate typealias Node = RefListNode<Element>
    internal typealias Index = Int
    internal typealias Indices = CountableRange<Int>
    internal typealias Iterator = IndexingIterator<RefList>

    fileprivate var root: Node

    required convenience init() {
        self.init(order: Node.defaultOrder)
    }

    required convenience init<S: Sequence>(_ elements: S) where S.Iterator.Element == Element {
        // TODO: Implement bulk loader
        self.init()
        self.append(contentsOf: elements)
    }

    init(order: Int) {
        self.root = Node(order: order)
    }

    internal var count: Int { return root.count }
    internal var startIndex: Int { return 0 }
    internal var endIndex: Int { return count }

    internal subscript(index: Int) -> Element {
        get {
            let (node, slot) = self.slot(of: index)
            return node.elements[slot]
        }
        set {
            precondition(newValue.parent == nil)
            let (node, slot) = self.slot(of: index)
            let old = node.elements[slot]
            node.elements[slot] = newValue
            newValue.parent = node
            old.parent = nil
        }
    }

    internal subscript(bounds: Range<Int>) -> MutableRangeReplaceableRandomAccessSlice<RefList> {
        get {
            return .init(base: self, bounds: bounds)
        }
        set {
            // Elements can only belong to a single RefList, but slices contain elements that are already in one.
            fatalError("RefList does not support range replacement.")
        }
    }

    internal func forEach(in range: Range<Int>? = nil, body: (Element) throws -> ()) rethrows {
        if let range = range, range != 0 ..< count {
            try root.forEach(range, body)
        }
        else {
            try root.forEach(body)
        }
    }

    internal func index(of element: Element) -> Int? {
        var node = element.parent!
        var offset = node.offset(of: element)
        while let parent = node.parent {
            offset += parent.offset(of: node)
            node = parent
        }
        precondition(node === root)
        return offset
    }

    private func slot(of offset: Int) -> (node: Node, slot: Int) {
        precondition(offset >= 0 && offset < count)
        var offset = offset
        var node = root
        while !node.isLeaf {
            let slot = node.slot(atOffset: offset)
            if slot.match {
                return (node, slot.index)
            }
            let child = node.children[slot.index]
            offset -= slot.offset - child.count
            node = child
        }
        return (node, offset)
    }

    internal func insert(_ element: Element, at index: Int) {
        precondition(element.parent == nil)
        precondition(index >= 0 && index <= count)
        var pos = count - index
        var splinter: (separator: Element, node: Node)? = nil
        var element = element
        root.edit(
            descend: { node in
                let slot = node.slot(atOffset: node.count - pos)
                if !slot.match {
                    // Continue descending.
                    pos -= node.count - slot.offset
                    return slot.index
                }
                if node.isLeaf {
                    // Found the insertion point. Insert, then start ascending.
                    node.insert(element, inSlot: slot.index)
                    if node.isTooLarge {
                        splinter = node.split()
                    }
                    return nil
                }
                // For internal nodes, put the new element in place of the old at the same offset,
                // then continue descending toward the next offset, inserting the old element.
                element = node.setElement(inSlot: slot.index, to: element)
                pos = node.children[slot.index + 1].count
                return slot.index + 1
            },
            ascend: { node, slot in
                node.count += 1
                if let s = splinter {
                    s.separator.parent = node
                    s.node.parent = node
                    node.elements.insert(s.separator, at: slot)
                    node.children.insert(s.node, at: slot + 1)
                    splinter = node.isTooLarge ? node.split() : nil
                }
            }
        )
        if let s = splinter {
            root = Node(left: root, separator: s.separator, right: s.node)
        }
        assert(element.parent != nil)
    }

    internal func insert<C: Collection>(contentsOf newElements: C, at index: Int) where C.Iterator.Element == Iterator.Element {
        // TODO: Implement bulk insertion using join.
        var i = index
        for element in newElements {
            self.insert(element, at: i)
            i += 1
        }
    }

    internal func append(_ newElement: Element) {
        self.insert(newElement, at: count)
    }

    internal func append<S: Sequence>(contentsOf newElements: S) where S.Iterator.Element == Iterator.Element {
        // TODO: Implement bulk insertion using join.
        var i = count
        for element in newElements {
            self.insert(element, at: i)
            i += 1
        }
    }

    /// Remove and return the element at the specified offset.
    ///
    /// - Note: When you need to perform multiple modifications on the same tree,
    ///   `BTreeCursor` provides an alternative interface that's often more efficient.
    /// - Complexity: O(log(`count`))
    @discardableResult
    internal func remove(at index: Int) -> Element {
        precondition(index >= 0 && index < count)
        var pos = count - index
        var matching: (node: Node, slot: Int)? = nil
        var old: Element? = nil
        root.edit(
            descend: { node in
                let slot = node.slot(atOffset: node.count - pos)
                if !slot.match {
                    // No match yet; continue descending.
                    assert(!node.isLeaf)
                    pos -= node.count - slot.offset
                    return slot.index
                }
                if node.isLeaf {
                    // The offset we're looking for is in a leaf node; we can remove it directly.
                    old = node.elements.remove(at: slot.index)
                    old!.parent = nil
                    node.count -= 1
                    return nil
                }
                // When the offset happens to fall in an internal node, remember the match and continue
                // removing the next offset (which is guaranteed to be in a leaf node).
                // We'll replace the removed element with this one during the ascend.
                matching = (node, slot.index)
                pos = node.children[slot.index + 1].count
                return slot.index + 1
            },
            ascend: { node, slot in
                node.count -= 1
                if let m = matching, m.node === node {
                    // We've removed the element at the next offset; put it back in place of the
                    // element we actually want to remove.
                    old!.parent = node
                    old = node.setElement(inSlot: m.slot, to: old!)
                    old!.parent = nil
                    matching = nil
                }
                if node.children[slot].isTooSmall {
                    node.fixDeficiency(slot)
                }
            }
        )
        if root.children.count == 1 {
            assert(root.elements.count == 0)
            root = root.children[0]
            root.parent = nil
        }
        precondition(old?.parent == nil)
        return old!
    }

    internal func removeSubrange(_ bounds: Range<Int>) {
        // TODO: Make this more efficient.
        for index in CountableRange(bounds).reversed() {
            self.remove(at: index)
        }
    }

    internal func replaceSubrange<C: Collection>(_ subrange: Range<Int>, with newElements: C) where C.Iterator.Element == Element {
        // TODO: Make this more efficient.
        self.removeSubrange(subrange)
        self.insert(contentsOf: newElements, at: subrange.lowerBound)
    }
}

fileprivate final class RefListNode<Element: RefListElement> {
    typealias Node = RefListNode<Element>

    var _parent: UnownedReference<RefListNode>?
    var elements: [Element]
    var children: [RefListNode]
    var count: Int = 0
    let order: Int
    var depth: Int


    static var defaultOrder: Int {
        return Swift.max(16383 / MemoryLayout<Element>.stride, 31)
    }

    init(order: Int, elements: [Element], children: [Node], count: Int) {
        precondition(elements.count <= order)
        precondition(children.count == 0 || children.count == elements.count + 1)
        self._parent = nil
        self.elements = elements
        self.children = children
        self.count = count
        self.order = order
        self.depth = (children.count == 0 ? 0 : children[0].depth + 1)
        elements.forEach { $0.parent = self }
        children.forEach { $0.parent = self }
    }

    convenience init(order: Int = RefListNode.defaultOrder) {
        self.init(order: order, elements: [], children: [], count: 0)
    }

    convenience init(left: Node, separator: Element, right: Node) {
        precondition(left.order == right.order && left.depth == right.depth)
        self.init(order: left.order, elements: [separator], children: [left, right], count: left.count + 1 + right.count)
    }

    convenience init(node: Node, slotRange: CountableRange<Int>) {
        if node.isLeaf {
            let elements = Array(node.elements[slotRange])
            self.init(order: node.order, elements: elements, children: [], count: elements.count)
        }
        else if slotRange.count == 0 {
            let n = node.children[slotRange.lowerBound]
            self.init(order: n.order, elements: n.elements, children: n.children, count: n.count)
        }
        else {
            let elements = Array(node.elements[slotRange])
            let children = Array(node.children[slotRange.lowerBound ... slotRange.upperBound])
            let count = children.reduce(elements.count) { $0 + $1.count }
            self.init(order: node.order, elements: elements, children: children, count: count)
        }
    }

    var parent: RefListNode? {
        get {
            return _parent?.value
        }
        set {
            if let p = newValue {
                _parent = UnownedReference(p)
            }
            else {
                _parent = nil
            }
        }
    }

    var maxChildren: Int { return order }
    var minChildren: Int { return (maxChildren + 1) / 2 }
    var maxElements: Int { return maxChildren - 1 }
    var minElements: Int { return minChildren - 1 }

    var isLeaf: Bool { return depth == 0 }
    var isTooSmall: Bool { return elements.count < minElements }
    var isTooLarge: Bool { return elements.count > maxElements }
    var isBalanced: Bool { return elements.count >= minElements && elements.count <= maxElements }
}

extension RefListNode {
    func edit(descend: (Node) -> Int?, ascend: (Node, Int) -> Void) {
        guard let slot = descend(self) else { return }
        let child = children[slot]
        child.edit(descend: descend, ascend: ascend)
        ascend(self, slot)
    }

    func setElement(inSlot slot: Int, to element: Element) -> Element {
        let old = elements[slot]
        elements[slot] = element
        element.parent = self
        old.parent = nil
        return old
    }

    func insert(_ element: Element, inSlot slot: Int) {
        elements.insert(element, at: slot)
        count += 1
        element.parent = self
    }

    func offset(of element: Element) -> Int {
        if isLeaf {
            return elements.index { $0 === element }!
        }
        var offset = 0
        var found = false
        for i in 0 ..< elements.count {
            offset += children[i].count
            if elements[i] === element { found = true; break }
            offset += 1
        }
        precondition(found)
        return offset
    }

    func offset(of child: Node) -> Int {
        var offset = 0
        var found = false
        for c in children {
            if c === child { found = true; break }
            offset += 1 + c.count
        }
        precondition(found)
        return offset
    }

    /// Return the slot of the element at `offset` in the subtree rooted at this node.
    func slot(atOffset offset: Int) -> (index: Int, match: Bool, offset: Int) {
        assert(offset >= 0 && offset <= count)
        if offset == count {
            return (index: elements.count, match: isLeaf, offset: count)
        }
        if isLeaf {
            return (offset, true, offset)
        }
        else if offset <= count / 2 {
            var p = 0
            for i in 0 ..< children.count - 1 {
                let c = children[i].count
                if offset == p + c {
                    return (index: i, match: true, offset: p + c)
                }
                if offset < p + c {
                    return (index: i, match: false, offset: p + c)
                }
                p += c + 1
            }
            let c = children.last!.count
            precondition(count == p + c, "Invalid B-Tree")
            return (index: children.count - 1, match: false, offset: count)
        }
        var p = count
        for i in (1 ..< children.count).reversed() {
            let c = children[i].count
            if offset == p - (c + 1) {
                return (index: i - 1, match: true, offset: offset)
            }
            if offset > p - (c + 1) {
                return (index: i, match: false, offset: p)
            }
            p -= c + 1
        }
        let c = children.first!.count
        precondition(p - c == 0, "Invalid B-Tree")
        return (index: 0, match: false, offset: c)
    }

    /// Split this node into two, removing the high half of the nodes and putting them in a splinter.
    ///
    /// - Returns: A splinter consisting of a separator and a node containing the higher half of the original node.
    func split() -> (separator: Element, node: Node) {
        assert(isTooLarge)
        return split(at: elements.count / 2)
    }

    /// Split this node into two at the key at index `median`, removing all elements at or above `median`
    /// and putting them in a splinter.
    ///
    /// - Returns: A splinter consisting of a separator and a node containing the higher half of the original node.
    func split(at median: Int) -> (separator: Element, node: Node) {
        let count = elements.count
        let separator = elements[median]
        let splinter = Node(node: self, slotRange: median + 1 ..< count)
        elements.removeSubrange(median ..< count)
        if isLeaf {
            self.count = median
        }
        else {
            children.removeSubrange(median + 1 ..< count + 1)
            self.count = median + children.reduce(0) { $0 + $1.count }
        }
        separator.parent = nil
        return (separator, splinter)
    }

    /// Reorganize the tree rooted at `self` so that the undersize child in `slot` is corrected.
    /// As a side effect of the process, `self` may itself become undersized, but all of its descendants
    /// become balanced.
    func fixDeficiency(_ slot: Int) {
        assert(!isLeaf && children[slot].isTooSmall)
        if slot > 0 && children[slot - 1].elements.count > minElements {
            rotateRight(slot)
        }
        else if slot < children.count - 1 && children[slot + 1].elements.count > minElements {
            rotateLeft(slot)
        }
        else if slot > 0 {
            // Collapse deficient slot into previous slot.
            collapse(slot - 1)
        }
        else {
            // Collapse next slot into deficient slot.
            collapse(slot)
        }
    }

    func rotateRight(_ slot: Int) {
        assert(slot > 0)

        let previous = children[slot - 1]
        let child = children[slot]

        let e = elements[slot - 1]
        child.elements.insert(e, at: 0)
        e.parent = child

        if !child.isLeaf {
            let lastGrandChildBeforeSlot = previous.children.removeLast()
            lastGrandChildBeforeSlot.parent = child
            child.children.insert(lastGrandChildBeforeSlot, at: 0)

            previous.count -= lastGrandChildBeforeSlot.count
            child.count += lastGrandChildBeforeSlot.count
        }
        let element = previous.elements.removeLast()
        element.parent = self
        elements[slot - 1] = element
        previous.count -= 1
        child.count += 1
    }

    func rotateLeft(_ slot: Int) {
        assert(slot < children.count - 1)
        let child = children[slot]
        let next = children[slot + 1]

        let e = elements[slot]
        e.parent = child
        child.elements.append(e)
        if !child.isLeaf {
            let firstGrandChildAfterSlot = next.children.remove(at: 0)
            firstGrandChildAfterSlot.parent = child
            child.children.append(firstGrandChildAfterSlot)

            next.count -= firstGrandChildAfterSlot.count
            child.count += firstGrandChildAfterSlot.count
        }
        let element = next.elements.remove(at: 0)
        element.parent = self
        elements[slot] = element
        child.count += 1
        next.count -= 1
    }

    func collapse(_ slot: Int) {
        assert(slot < children.count - 1)
        let target = children[slot]

        let collapsed = children.remove(at: slot + 1)
        collapsed.parent = nil

        let e = elements.remove(at: slot)
        e.parent = target
        target.elements.append(e)
        target.count += 1

        collapsed.elements.forEach { $0.parent = target }
        target.elements.append(contentsOf: collapsed.elements)
        target.count += collapsed.count
        if !collapsed.isLeaf {
            collapsed.children.forEach { $0.parent = target }
            target.children.append(contentsOf: collapsed.children)
        }
        assert(target.isBalanced)
    }
}

extension RefListNode {
    func forEach(_ body: (Element) throws -> ()) rethrows {
        if isLeaf {
            try elements.forEach(body)
        }
        else {
            for i in 0 ..< elements.count {
                try children[i].forEach(body)
                try body(elements[i])
            }
            try children[elements.count].forEach(body)
        }
    }

    func forEach(_ range: Range<Int>, _ body: (Element) throws -> ()) rethrows {
        if isLeaf {
            for element in elements[range] {
                try body(element)
            }
            return
        }
        var c = range.count
        let slot = self.slot(atOffset: range.lowerBound)
        guard range.count > 0 else { return }
        if !slot.match {
            let child = children[slot.index]
            let childCount = child.count
            let childStartOffset = slot.offset - childCount
            let childRange: Range<Int> = range.lowerBound - childStartOffset ..< min(childCount, range.upperBound - childStartOffset)
            try child.forEach(childRange, body)
            c -= childRange.count
        }
        var index = slot.index
        while c > 0 {
            try body(elements[index])
            c -= 1
            guard c > 0 else { break }
            index += 1
            let child = children[index]
            if c >= child.count {
                try child.forEach(body)
                c -= child.count
            }
            else {
                try child.forEach(0 ..< c, body)
                c = 0
            }
        }
    }
}
