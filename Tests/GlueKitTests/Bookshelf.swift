//
//  Bookshelf.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-02.
//  Copyright © 2015–2017 Károly Lőrentey.
//

import Foundation
import GlueKit
import XCTest

// Let's suppose we're writing an app for maintaining a catalogue for your books.
// Here is what the model could look like.

private class Author: Hashable {
    let name: Variable<String>
    let yearOfBirth: Variable<Int>

    init(name: String, yearOfBirth: Int) {
        self.name = .init(name)
        self.yearOfBirth = .init(yearOfBirth)
    }

    var hashValue: Int { return name.value.hashValue }
    static func == (a: Author, b: Author) -> Bool {
        return a.name.value == b.name.value && a.yearOfBirth.value == b.yearOfBirth.value
    }
}

private class Book: Hashable {
    let title: Variable<String>
    let authors: SetVariable<Author>
    let publicationYear: Variable<Int>
    let pages: Variable<Int>

    init(title: String, authors: Set<Author>, publicationYear: Int, pages: Int) {
        self.title = .init(title)
        self.authors = SetVariable(authors)
        self.publicationYear = .init(pages)
        self.pages = .init(pages)
    }

    var hashValue: Int { return title.value.hashValue }
    static func == (a: Book, b: Book) -> Bool {
        return (a.title.value == b.title.value
            && a.authors.value == b.authors.value
            && a.publicationYear.value == b.publicationYear.value
            && a.pages.value == b.pages.value)
    }
}

private class Bookshelf {
    let location: Variable<String>
    let books: ArrayVariable<Book>

    init(location: String, books: [Book] = []) {
        self.location = .init(location)
        self.books = .init(books)
    }
}

private struct Fixture {
    let stephenson = Author(name: "Neal Stephenson", yearOfBirth: 1959)
    let pratchett = Author(name: "Terry Pratchett", yearOfBirth: 1948)
    let gaiman = Author(name: "Neil Gaiman", yearOfBirth: 1960)
    let knuth = Author(name: "Donald E. Knuth", yearOfBirth: 1938)

    lazy var colourOfMagic: Book = .init(title: "The Colour of Magic", authors: [self.pratchett], publicationYear: 1983, pages: 206)
    lazy var smallGods: Book = .init(title: "Small Gods", authors: [self.pratchett], publicationYear: 1992, pages: 284)
    lazy var seveneves: Book = .init(title: "Seveneves", authors: [self.stephenson], publicationYear: 2015, pages: 880)
    lazy var goodOmens: Book = .init(title: "Good Omens", authors: [self.pratchett, self.gaiman], publicationYear: 1990, pages: 288)
    lazy var americanGods: Book = .init(title: "American Gods", authors: [self.gaiman], publicationYear: 2001, pages: 465)
    lazy var cryptonomicon: Book = .init(title: "Cryptonomicon", authors: [self.stephenson], publicationYear: 1999, pages: 918)
    lazy var anathem: Book = .init(title: "Anathem", authors: [self.stephenson], publicationYear: 2008, pages: 928)
    lazy var texBook: Book = .init(title: "The TeXBook", authors: [self.knuth], publicationYear: 1984, pages: 483)
    lazy var taocp1: Book = .init(title: "The Art of Computer Programming vol. 1: Fundamental Algorithms. 3rd ed.", authors: [self.knuth], publicationYear: 1997, pages: 650)

    lazy var topShelf: Bookshelf = .init(location: "Top", books: [self.colourOfMagic, self.smallGods, self.seveneves, self.goodOmens, self.americanGods])
    lazy var bottomShelf: Bookshelf = .init(location: "Bottom", books: [self.cryptonomicon, self.anathem, self.texBook, self.taocp1])
    lazy var shelves: ArrayVariable<Bookshelf> = [self.topShelf, self.bottomShelf]
}

class BookshelfTests: XCTestCase {

    func testAllTitles() {
        var f = Fixture()
        // Let's get an array of the title of each book in the library.
        let allTitles = f.shelves.flatMap{$0.books}.map{$0.title}
        XCTAssertEqual(allTitles.value, ["The Colour of Magic", "Small Gods", "Seveneves", "Good Omens", "American Gods", "Cryptonomicon", "Anathem", "The TeXBook", "The Art of Computer Programming vol. 1: Fundamental Algorithms. 3rd ed."])
    }

    func testBooksByStephenson() {
        var f = Fixture()
        let booksByStephenson = f.shelves.flatMap{$0.books}.filter { book in book.authors.observableContains(f.stephenson) }
        XCTAssertEqual(booksByStephenson.value, [f.seveneves, f.cryptonomicon, f.anathem])
    }
}





