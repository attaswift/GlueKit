//: Playground - noun: a place where people can play

import GlueKit
import XCPlayground

#if false

class File {
    let name: Variable<String>

    init(name: String) { self.name = Variable(name) }
}

class Folder {
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

let filenames = root.subfolders.selectEach{$0.files}.selectEach{$0.name}

var change = ArrayChange<String>(initialCount: filenames.count)

func changeToString(_ change: ArrayChange<String>) -> String {
    var desc = ""
    let mods = change.modifications.map { m in "\n\(m)" }.joined(separator: "")
    desc.append(mods)
    return desc
}
let connection = filenames.futureChanges.connect { c in
    let page = XCPlaygroundPage.currentPage
    page.captureValue(value: changeToString(c), withIdentifier: "change")
    change.merge(with: c)
    page.captureValue(value: changeToString(change), withIdentifier: "merged")
    page.captureValue(value: change.modifications.count, withIdentifier: "count")
}

// Add a new file to folder 1
folder1.files.value
folder1.files.insert(File(name: "1/b2"), at: 2)
change

// Rename a file in folder 2
folder2.files[0].name.value = "2/a.renamed"
change

// Delete a file from folder 1
folder1.files.remove(at: 1)
change

// Add a new subfolder between folders 1 and 2
let folder3 = Folder(name: "Folder 3", files: [
    File(name: "3/1"),
    ])

root.subfolders.insert(folder3, at: 1)
change

// Delete folder 2
root.subfolders.remove(at: 2)
change

// Add a file to the root folder. (This should be an unrelated change.)
root.files.append(File(name: "/a"))
change

// Rename folder 1. (This should be an unrelated change.)
folder1.name.value = "Foobar"

change
let s = change.modifications.map { "\($0)" }.joined(separator: "\n")
s

connection.disconnect()
#endif
