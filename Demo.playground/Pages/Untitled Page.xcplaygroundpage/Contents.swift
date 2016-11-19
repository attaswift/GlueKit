import GlueKit
import XCPlayground

// Let's suppose we're writing an app for maintaining a catalogue for your books.
// Here is what the model could look like.

class Author: Hashable, CustomStringConvertible {
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
    var description: String { return "Author(\(name.value))" }
}

class Book: Hashable, CustomStringConvertible {
    let title: Variable<String>
    let authors: SetVariable<Author>
    let publicationYear: Variable<Int>
    let pages: Variable<Int>

    init(title: String, authors: Set<Author>, publicationYear: Int, pages: Int) {
        self.title = .init(title)
        self.authors = .init(authors)
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
    var description: String { return "Book(\(title.value))" }
}

class Bookshelf {
    let location: Variable<String>
    let books: ArrayVariable<Book>

    init(location: String, books: [Book] = []) {
        self.location = .init(location)
        self.books = .init(books)
    }
}

// Let's create a couple of example books and arrange them on some bookshelves.

let stephenson = Author(name: "Neal Stephenson", yearOfBirth: 1959)
let pratchett = Author(name: "Terry Pratchett", yearOfBirth: 1948)
let gaiman = Author(name: "Neil Gaiman", yearOfBirth: 1960)
let knuth = Author(name: "Donald E. Knuth", yearOfBirth: 1938)

let colourOfMagic = Book(title: "The Colour of Magic", authors: [pratchett], publicationYear: 1983, pages: 206)
let smallGods = Book(title: "Small Gods", authors: [pratchett], publicationYear: 1992, pages: 284)
let seveneves = Book(title: "Seveneves", authors: [stephenson], publicationYear: 2015, pages: 880)
let goodOmens = Book(title: "Good Omens", authors: [pratchett, gaiman], publicationYear: 1990, pages: 288)
let americanGods = Book(title: "American Gods", authors: [gaiman], publicationYear: 2001, pages: 465)
let cryptonomicon = Book(title: "Cryptonomicon", authors: [stephenson], publicationYear: 1999, pages: 918)
let anathem = Book(title: "Anathem", authors: [stephenson], publicationYear: 2008, pages: 928)
let texBook = Book(title: "The TeXBook", authors: [knuth], publicationYear: 1984, pages: 483)
let taocp1 = Book(title: "The Art of Computer Programming vol. 1: Fundamental Algorithms. 3rd ed.", authors: [knuth], publicationYear: 1997, pages: 650)

let topShelf = Bookshelf(location: "Top", books: [colourOfMagic, smallGods, seveneves, goodOmens, americanGods])
let bottomShelf = Bookshelf(location: "Bottom", books: [cryptonomicon, anathem, texBook, taocp1])

let shelves = ArrayVariable<Bookshelf>([topShelf, bottomShelf])


// Now let's create some interesting queries on this small library of books!


// Let's get an array of the title of each book in the library.
let allTitles = shelves.flatMap{$0.books}.map{$0.title}
allTitles.value

let allAuthors = shelves.flatMap{$0.books}.distinctUnion().flatMap{$0.authors}
allAuthors.value

// Here are all books that have Neal Stephenson as one of their authors.
let booksByStephenson = shelves.flatMap{$0.books}.filter { book in book.authors.observableContains(stephenson) }
booksByStephenson.value

// Let's imagine Stephenson was a co-author of The TeXBook, and add him to its author list.
texBook.authors.insert(stephenson)

// `booksByStephenson` automatically updates to reflect the change.
booksByStephenson.value


// How many books do I have?
let bookCount = shelves.flatMap{$0.books}.observableCount
bookCount.value

// What if I buy a new book?
let mort = Book(title: "Mort", authors: [pratchett], publicationYear: 1987, pages: 315)
topShelf.books.append(mort)

bookCount
allTitles

