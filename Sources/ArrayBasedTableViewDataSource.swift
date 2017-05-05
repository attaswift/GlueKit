//
//  ArrayBasedTableViewDataSource.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2017-04-24.
//  Copyright © 2017. Károly Lőrentey. All rights reserved.
//

#if os(iOS)
import UIKit

extension IndexSet {
    func toIndexPaths(section: Int = 0) -> [IndexPath] {
        return self.map { IndexPath(row: $0, section: section) }
    }
}

public class ArrayBasedTableViewDataSource<Item: Hashable, Cell: UITableViewCell>: NSObject, UITableViewDataSource {
    public let tableView: UITableView
    public let reuseIdentifier: String
    public let cellLoader: (Item, Cell) -> Void

    private var _itemsRef = Variable<AnyObservableArray<Item>>(.constant([]))
    private var _items: AnyObservableArray<Item>
    private var _changes: AnySource<ArrayChange<Item>>

    public var items: AnyObservableArray<Item> {
        get { return _itemsRef.value }
        set { _itemsRef.value = newValue }
    }

    private struct Sink<Item: Hashable, Cell: UITableViewCell>: UniqueOwnedSink {
        typealias Owner = ArrayBasedTableViewDataSource<Item, Cell>
        unowned(unsafe) let owner: Owner
        func receive(_ change: ArrayChange<Item>) { owner.receive(change) }
    }

    public init(tableView: UITableView, reuseIdentifier: String, cellLoader: @escaping (Item, Cell) -> Void) {
        self.tableView = tableView
        self.reuseIdentifier = reuseIdentifier
        self.cellLoader = cellLoader
        self._items = _itemsRef.unpacked()
        self._changes = _items.changes
        super.init()

        self._changes.add(Sink<Item, Cell>(owner: self))
    }

    deinit {
        self._changes.remove(Sink<Item, Cell>(owner: self))
    }

    public convenience init(tableView: UITableView, reuseIdentifier: String) {
        self.init(tableView: tableView, reuseIdentifier: reuseIdentifier, cellLoader: { item, cell in
            cell.textLabel!.text = "\(item)"
        })
    }

    private func receive(_ change: ArrayChange<Item>) {
        guard !change.isEmpty else { return }
        let batch = change.separated()
        print("Batch: count=\(change.initialCount)/\(change.finalCount), deleted=\(Array(batch.deleted)), inserted=\(Array(batch.inserted)), moved=\(batch.moved)")
        assert(batch.change.finalCount == items.count)

        tableView.beginUpdates()
        tableView.deleteRows(at: batch.deleted.toIndexPaths(), with: .fade)
        tableView.insertRows(at: batch.inserted.toIndexPaths(), with: .fade)
        for (from, to) in batch.moved {
            tableView.moveRow(at: IndexPath(row: from, section: 0), to: IndexPath(row: to, section: 0))
            if let cell = tableView.cellForRow(at: IndexPath(row: from, section: 0)) as? Cell {
                cellLoader(items[to], cell)
            }
        }
        tableView.endUpdates()
    }

    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section == 0 else { return 0 }
        return items.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        precondition(indexPath.section == 0)
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! Cell
        cellLoader(items[indexPath.row], cell)
        return cell
    }


    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }

    public func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return nil
    }


    public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    public func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return false
    }
}

#endif
