//
//  SelectOperatorTests.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2015-12-06.
//  Copyright © 2015 Károly Lőrentey. All rights reserved.
//

import XCTest
import GlueKit

private class File {
    let name: Variable<String>

    init(name: String) { self.name = Variable(name) }
}

private class Folder {
    let name: Variable<String>
    let files: ArrayVariable<File> = []
    let subfolders: ArrayVariable<Folder> = []

    init(name: String, files: [File] = []) {
        self.name = Variable(name)
        self.files.value = files
    }

    init(name: String, subfolders: [Folder]) {
        self.name = Variable(name)
        self.subfolders.value = subfolders
    }
}

class SelectFromArrayTests: XCTestCase {

    func testSelectDirectValueAccess() {
        let folder1 = Folder(name: "Folder 1", files: [
            File(name: "1/a"),
            File(name: "1/b"),
            File(name: "1/c"),
            ])
        let folder2 = Folder(name: "Folder 2", files: [
            File(name: "2/a"),
            File(name: "2/b"),
        ])
        let root = Folder(name: "Root", subfolders: [folder1, folder2])

        // Get all files in subfolders of the root folder.
        let files = root.subfolders.selectEach{$0.files}
        XCTAssertEqual(files.count, 5)
        XCTAssertEqual(files.value.map { $0.name.value }, ["1/a", "1/b", "1/c", "2/a", "2/b"])

        // Get the filenames of all files in subfolders of the root folder.
        let filenames = root.subfolders.selectEach{$0.files}.selectEach{$0.name}
        XCTAssertEqual(filenames.count, 5)
        XCTAssertEqual(filenames.value, ["1/a", "1/b", "1/c", "2/a", "2/b"])

        // Add a new file to folder 1
        folder1.files.insert(File(name: "1/b2"), at: 2)

        XCTAssertEqual(files.count, 6)
        XCTAssertEqual(filenames.count, 6)
        XCTAssertEqual(files.value.map { $0.name.value }, ["1/a", "1/b", "1/b2", "1/c", "2/a", "2/b"])
        XCTAssertEqual(filenames.value, ["1/a", "1/b", "1/b2", "1/c", "2/a", "2/b"])

        // Rename a file in folder 2
        folder2.files[0].name.value = "2/a.renamed"

        XCTAssertEqual(files.count, 6)
        XCTAssertEqual(filenames.count, 6)
        XCTAssertEqual(files.value.map { $0.name.value }, ["1/a", "1/b", "1/b2", "1/c", "2/a.renamed", "2/b"])
        XCTAssertEqual(filenames.value, ["1/a", "1/b", "1/b2", "1/c", "2/a.renamed", "2/b"])

        // Delete a file from folder 1
        folder1.files.remove(at: 1)

        XCTAssertEqual(files.count, 5)
        XCTAssertEqual(filenames.count, 5)
        XCTAssertEqual(files.value.map { $0.name.value }, ["1/a", "1/b2", "1/c", "2/a.renamed", "2/b"])
        XCTAssertEqual(filenames.value, ["1/a", "1/b2", "1/c", "2/a.renamed", "2/b"])

        // Add a new subfolder between folders 1 and 2
        let folder3 = Folder(name: "Folder 3", files: [
            File(name: "3/1"),
        ])
        root.subfolders.insert(folder3, at: 1)

        XCTAssertEqual(files.count, 6)
        XCTAssertEqual(filenames.count, 6)
        XCTAssertEqual(files.value.map { $0.name.value }, ["1/a", "1/b2", "1/c", "3/1", "2/a.renamed", "2/b"])
        XCTAssertEqual(filenames.value, ["1/a", "1/b2", "1/c", "3/1", "2/a.renamed", "2/b"])

        // Delete folder 2
        root.subfolders.remove(at: 2)

        XCTAssertEqual(files.count, 4)
        XCTAssertEqual(filenames.count, 4)
        XCTAssertEqual(files.value.map { $0.name.value }, ["1/a", "1/b2", "1/c", "3/1"])
        XCTAssertEqual(filenames.value, ["1/a", "1/b2", "1/c", "3/1"])

        // Add a file to the root folder. (This should be an unrelated change.)
        root.files.append(File(name: "/a"))

        XCTAssertEqual(files.count, 4)
        XCTAssertEqual(filenames.count, 4)
        XCTAssertEqual(files.value.map { $0.name.value }, ["1/a", "1/b2", "1/c", "3/1"])
        XCTAssertEqual(filenames.value, ["1/a", "1/b2", "1/c", "3/1"])

        // Rename folder 1. (This should be an unrelated change.)
        folder1.name.value = "Foobar"

        XCTAssertEqual(files.count, 4)
        XCTAssertEqual(filenames.count, 4)
        XCTAssertEqual(files.value.map { $0.name.value }, ["1/a", "1/b2", "1/c", "3/1"])
        XCTAssertEqual(filenames.value, ["1/a", "1/b2", "1/c", "3/1"])
}

    func testSelectObservingChanges() {
        let folder1 = Folder(name: "Folder 1", files: [
            File(name: "1/a"),
            File(name: "1/b"),
            File(name: "1/c"),
            ])
        let folder2 = Folder(name: "Folder 2", files: [
            File(name: "2/a"),
            File(name: "2/b"),
            ])
        let root = Folder(name: "Root", subfolders: [folder1, folder2])

        // Get the filenames of all files in subfolders of the root folder.
        let filenames = root.subfolders.selectEach{$0.files}.selectEach{$0.name}

        var changes = [ArrayChange<String>]()
        var expected = [ArrayChange<String>]()
        let c1 = filenames.futureChanges.connect { changes.append($0) }

        // Add a new file to folder 1
        folder1.files.insert(File(name: "1/b2"), at: 2)

        expected.append(ArrayChange(initialCount: 5, modification: .insert("1/b2", at: 2)))

        XCTAssertTrue(changes.elementsEqual(expected, by: ==))
        XCTAssertEqual(filenames.value, ["1/a", "1/b", "1/b2", "1/c", "2/a", "2/b"])

        // Rename a file in folder 2
        folder2.files[0].name.value = "2/a.renamed"

        expected.append(ArrayChange(initialCount: 6, modification: .replaceAt(4, with: "2/a.renamed")))

        XCTAssertTrue(changes.elementsEqual(expected, by: ==))
        XCTAssertEqual(filenames.value, ["1/a", "1/b", "1/b2", "1/c", "2/a.renamed", "2/b"])

        // Delete a file from folder 1
        folder1.files.remove(at: 1)

        expected.append(ArrayChange(initialCount: 6, modification: .removeAt(1)))

        XCTAssertTrue(changes.elementsEqual(expected, by: ==))
        XCTAssertEqual(filenames.value, ["1/a", "1/b2", "1/c", "2/a.renamed", "2/b"])

        // Add a new subfolder between folders 1 and 2
        let folder3 = Folder(name: "Folder 3", files: [
            File(name: "3/1"),
            ])
        root.subfolders.insert(folder3, at: 1)

        expected.append(ArrayChange(initialCount: 5, modification: .insert("3/1", at: 3)))

        XCTAssertTrue(changes.elementsEqual(expected, by: ==))
        XCTAssertEqual(filenames.value, ["1/a", "1/b2", "1/c", "3/1", "2/a.renamed", "2/b"])

        // Delete folder 2
        root.subfolders.remove(at: 2)

        expected.append(ArrayChange(initialCount: 6, modification: .replaceRange(4 ..< 6, with: [])))

        XCTAssertTrue(changes.elementsEqual(expected, by: ==))
        XCTAssertEqual(filenames.value, ["1/a", "1/b2", "1/c", "3/1"])

        // Add a file to the root folder. (This should be an unrelated change.)
        root.files.append(File(name: "/a"))

        XCTAssertTrue(changes.elementsEqual(expected, by: ==))
        XCTAssertEqual(filenames.value, ["1/a", "1/b2", "1/c", "3/1"])

        // Rename folder 1. (This should be an unrelated change.)
        folder1.name.value = "Foobar"

        XCTAssertTrue(changes.elementsEqual(expected, by: ==))
        XCTAssertEqual(filenames.value, ["1/a", "1/b2", "1/c", "3/1"])

        c1.disconnect()

        let reducedChanges = changes.reduce(ArrayChange(initialCount: 5)) { m, c in m.merged(with: c) }
        let expectedreducedMods: [ArrayModification<String>] = [
            .replaceAt(1, with: "1/b2"),
            .replaceRange(3 ..< 5, with: ["3/1"])
        ]
        XCTAssertTrue(reducedChanges.modifications.elementsEqual(expectedreducedMods, by: ==))
    }
}

