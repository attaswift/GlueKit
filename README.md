# GlueKit

[![Swift 3](https://img.shields.io/badge/Swift-3.0-blue.svg)](https://swift.org) 
[![License](https://img.shields.io/badge/licence-MIT-blue.svg)](https://github.com/lorentey/GlueKit/blob/master/LICENSE.md)
[![Platform](https://img.shields.io/badge/platforms-macOS%20∙%20iOS%20∙%20watchOS%20∙%20tvOS-blue.svg)](https://developer.apple.com/platforms/)

[![Build Status](https://travis-ci.org/lorentey/GlueKit.svg?branch=master)](https://travis-ci.org/lorentey/GlueKit)
[![Code Coverage](https://codecov.io/github/lorentey/GlueKit/coverage.svg?branch=master)](https://codecov.io/github/lorentey/GlueKit?branch=master)

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg)](https://github.com/Carthage/Carthage)
[![CocoaPod Version](https://img.shields.io/cocoapods/v/GlueKit.svg)](http://cocoapods.org/pods/GlueKit)

> :warning: **WARNING** :warning: This project is in a _prerelease_ state. There
> is active work going on that will result in API changes that can/will break
> code while things are finished. Use with caution.

GlueKit is a Swift framework for creating observables and manipulating them in interesting and useful ways.
It is called GlueKit because it lets you stick stuff together. 

GlueKit contains type-safe analogues for Cocoa's [Key-Value Coding][KVC] and [Key-Value Observing][KVO] subsystems, 
written in pure Swift.
Besides providing the basic observation mechanism, GlueKit also supports full-blown *key path*
observing, where a sequence of properties starting at a particular entity is observed at once. (E.g., you can observe
a person's best friend's favorite color, which might change whenever the person gets a new best friend, or when the friend
changes their mind about which color they like best.)

[KVC]: https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/KeyValueCoding/Articles/Overview.html
[KVO]: https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/KeyValueObserving/KeyValueObserving.html

(Note though that GlueKit's keys are functions so they aren't as easy to serialize as KVC's string-based keys and key paths.
It is definitely possible to implement serializable type-safe keys in Swift; but it involves some boilerplate code 
that's better handled by code generation or core language enhancements such as property behaviors or improved 
reflection capabilities.)

Like KVC/KVO, GlueKit supports observing not only individual values, but also collections like sets or arrays.
This includes full support for key path observing, too -- e.g., you can observe a person's children's children 
as a single set.
These observable collections report fine-grained incremental changes (e.g., "'foo' was inserted at index 5"), allowing
you to efficiently react to their changes.

Beyond key path observing, GlueKit also provides a rich set of transformations and combinations for observables
as a more flexible and extensible Swift version of KVC's 
[collection operators][KVC ops]. E.g., given an observable array of integers, you can (efficiently!) observe 
the sum of its elements; you can filter it for elements that match a particular predicate; you can get an observable
concatenation of it with another observable array; and you can do much more.

[KVC ops]: https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/KeyValueCoding/Articles/CollectionOperators.html

You can use GlueKit's observable arrays to efficiently provide data to a `UITableView` or `UICollectionView`, including
providing them with incremental changes for animated updates. This functionality is roughly equivalent to what
[`NSFetchedResultsController`][NSFRC] does in Core Data.

[NSFRC]: https://developer.apple.com/reference/coredata/nsfetchedresultscontroller

GlueKit is written in pure Swift; it does not require the Objective-C runtime for its functionality. 
However, it does provide easy-to-use adapters that turn KVO-compatible key paths on NSObjects into GlueKit observables.

GlueKit hasn't been officially released yet. Its API is still in flux, and it has wildly outdated and woefully 
incomplete documentation. However, the project is getting close to a feature set that would make a coherent 1.0 version;
I expect to have a useful first release before the end of 2016.

##  Presentation

Károly gave a talk on GlueKit during [Functional Swift Conference 2016][FunSwift16] in Budapest.
[Watch the video][funvideo] or [read the slides][slides].

[FunSwift16]: http://2016.funswiftconf.com
[slides]: https://vellum.tech/assets/FunSwift2016%20-%20GlueKit.pdf
[funvideo]: https://www.youtube.com/watch?v=98jsahDV4ts

## Installation
### CocoaPods

If you use CocoaPods, you can start using GlueKit by including it as a dependency in your  `Podfile`:

```
pod 'GlueKit', :git => 'https://github.com/lorentey/GlueKit.git'
```

(There are no official releases of GlueKit yet; the API is incomplete and very unstable for now.)

### Carthage

For Carthage, add the following line to your `Cartfile`:

```
github "lorentey/GlueKit" "<commit-hash>"
```

(You have to use a specific commit hash, because there are no official releases of GlueKit yet; the API is incomplete and very unstable for now.)

### Swift Package Manager

For Swift Package Manager, add the following entry to the dependencies list inside your `Package.swift` file:

```
.Package(url: "https://github.com/lorentey/GlueKit.git", branch: master)
```

### Standalone Development

If you don't use CocoaPods, Carthage or SPM, you need to clone GlueKit, [BTree][btree] and [SipHash][siphash], 
and add references to their `xcodeproj` files to your project's workspace. You may put the clones wherever you like,
but if you use Git for your app development, it is a good idea to set them up as submodules of your app's top-level 
Git repository.

[btree]: https://github.com/lorentey/BTree
[siphash]: https://github.com/lorentey/SipHash

To link your application binary with GlueKit, just add `GlueKit.framework`, `BTree.framework` and `SipHash.framework`
from the BTree project to the Embedded Binaries section of your app target's General page in Xcode.
As long as the GlueKit and BTree project files are referenced in your workspace, these frameworks will be listed in 
the "Choose items to add" sheet that opens when you click on the "+" button of your target's Embedded Binaries list.

There is no need to do any additional setup beyond adding the framework targets to Embedded Binaries.

### Working on GlueKit Itself

If you want to do some work on GlueKit on its own, without embedding it in an application, 
simply clone this repo with the `--recursive` option, open `GlueKit.xcworkspace`, and start hacking.

```
git clone --recursive https://github.com/lorentey/GlueKit.git GlueKit
open GlueKit/GlueKit.xcworkspace
```

### Importing GlueKit

Once you've made GlueKit available in your project, you need to import it at the top of each  `.swift` file in 
which you want to use its features:

```
import GlueKit
```

## Similar frameworks

Some of GlueKit's constructs can be matched with those in discrete reactive frameworks, such as 
[ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa), 
[RxSwift](https://github.com/ReactiveX/RxSwift), 
[ReactKit](https://github.com/ReactKit/ReactKit),
[Interstellar](https://github.com/JensRavens/Interstellar), and others. 
Sometimes GlueKit even uses the same name for the same concept. But often it doesn't (sorry).

GlueKit concentrates on creating a useful model for observables, rather than trying to unify 
observable-like things with task-like things. 
GlueKit explicitly does not attempt to directly model networking operations 
(although a networking support library could certainly use GlueKit to implement some of its features).
As such, GlueKit's source/signal/stream concept transmits simple values; it doesn't wrap them in
 `Event`s. 


I have several reasons I chose to create GlueKit instead of just using a better established and
bug-free library:

- I wanted to have some experience with reactive stuff, and you can learn a lot about a paradigm by 
  trying to construct its foundations on your own. The idea is that I start simple and add things as 
  I find I need them. I want to see if I arrive at the same problems and solutions as the 
  Smart People who created the popular frameworks. Some common reactive patterns are not obviously 
  right at first glance.
- I wanted to experiment with reentrant observables, where an observer is allowed to trigger updates 
  to the observable to which it's connected. I found no well-known implementation of Observable that 
  gets this *just right*.
- Building a library is a really fun diversion!

## Overview

[The GlueKit Overview](https://github.com/lorentey/GlueKit/blob/master/Documentation/Overview.md)
describes the basic concepts of GlueKit.

## Appetizer

Let's say you're writing a bug tracker application that has a list of projects, each with its own 
set of issues. With GlueKit, you'd use `Variable`s to define your model's attributes and relationships:

```Swift
class Project {
    let name: Variable<String>
    let issues: ArrayVariable<Issue>
}

class Account {
    let name: Variable<String>
    let email: Variable<String>
}

class Issue {
    let identifier: Variable<String>
    let owner: Variable<Account>
    let isOpen: Variable<Bool>
    let created: Variable<NSDate>
}

class Document {
    let accounts: ArrayVariable<Account>
    let projects: ArrayVariable<Project>
}
```

You can use a `let observable: Variable<Foo>` like you would a `var raw: Foo` property, except 
you need to write `observable.value` whenever you'd write `raw`:

```Swift
// Raw Swift       ===>      // GlueKit                                    
var a = 42          ;        let b = Variable<Int>(42) 
print("a = \(a)")   ;        print("b = \(b.value\)")
a = 7               ;        b.value = 7
```

Given the model above, in Cocoa you could specify key paths for accessing various parts of the model from a
`Document` instance. For example, to get the email addresses of all issue owners in one big unsorted array, 
you'd use the Cocoa key path `"projects.issues.owner.email"`. GlueKit is able to do this too, although
it uses a specially constructed Swift closure to represent the key path:

```Swift
let cocoaKeyPath: String = "projects.issues.owner.email"

let swiftKeyPath: Document -> AnyObservableValue<[String]> = { document in 
    document.projects.flatMap{$0.issues}.flatMap{$0.owner}.map{$0.email} 
}
```

(The type declarations are included to make it clear that GlueKit is fully type-safe. Swift's type inference is able
to find these out automatically, so typically you'd omit specifying types in declarations like this.)
The GlueKit syntax is certainly much more verbose, but in exchange it is typesafe, much more flexible, and also extensible. 
Plus, there is a visual difference between selecting a single value (`map`) or a collection of values (`flatMap`), 
which alerts you that using this key path might be more expensive than usual. (GlueKit's key paths are really just 
combinations of observables. `map` is a combinator that is used to build one-to-one key paths; there are many other
interesting combinators available.)

In Cocoa, you would get the current list of emails using KVC's accessor method. In GlueKit, if you give the key path a
document instance, it returns an `AnyObservableValue` that has a `value` property that you can get. 

```Swift
let document: Document = ...
let cocoaEmails: AnyObject? = document.valueForKeyPath(cocoaKeyPath)
let swiftEmails: [String] = swiftKeyPath(document).value
```

In both cases, you get an array of strings. However, Cocoa returns it as an optional `AnyObject` that you'll need to
unwrap and cast to the correct type yourself (you'll want to hold your nose while doing so). Boo! 
GlueKit knows what type the result is going to be, so it gives it to you straight. Yay!

Neither Cocoa nor GlueKit allows you to update the value at the end of this key path; however, with Cocoa, you only find
this out at runtime, while with GlueKit, you get a nice compiler error:

```Swift
// Cocoa: Compiles fine, but oops, crash at runtime
document.setValue("karoly@example.com", forKeyPath: cocoaKeyPath)
// GlueKit/Swift: error: cannot assign to property: 'value' is a get-only property
swiftKeyPath(document).value = "karoly@example.com"
```

You'll be happy to know that one-to-one key paths are assignable in both Cocoa and GlueKit:

```Swift
let issue: Issue = ...
/* Cocoa */   issue.setValue("karoly@example.com", forKeyPath: "owner.email") // OK
/* GlueKit */ issue.owner.map{$0.email}.value = "karoly@example.com"  // OK
```

(In GlueKit, you generally just use the observable combinators directly instead of creating key path entities.
So we're going to do that from now on. Serializable type-safe key paths require additional work, which is better
provided by a potentional future model object framework built on top of GlueKit.)

More interestingly, you can ask to be notified whenever a key path changes its value.

```Swift
// GlueKit
let c = document.projects.flatMap{$0.issues}.flatMap{$0.owner}.map{$0.name}.connect { emails in 
    print("Owners' email addresses are: \(emails)")
}
// Call c.disconnect() when you get bored of getting so many emails.

// Cocoa
class Foo {
    static let context: Int8 = 0
    let document: Document
    
    init(document: Document) {
        self.document = document
        document.addObserver(self, forKeyPath: "projects.issues.owner.email", options: .New, context:&context)
    }
    deinit {
        document.removeObserver(self, forKeyPath: "projects.issues.owner.email", context: &context)
    }
    func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, 
                                change change: [String : AnyObject]?, 
                                context context: UnsafeMutablePointer<Void>) {
        if context == &self.context {
	    print("Owners' email addresses are: \(change[NSKeyValueChangeNewKey]))
        }
        else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
}
```

Well, Cocoa is a mouthful, but people tend to wrap this up in their own abstractions. In both cases, a new set of emails is
printed whenever the list of projects changes, or the list of issues belonging to any project changes, or the owner of any
issue changes, or if the email address is changed on an individual account.


To present a more down-to-earth example, let's say you want to create a view model for a project summary screen that
displays various useful data about the currently selected project. GlueKit's observable combinators make it simple to
put together data derived from our model objects. The resulting fields in the view model are themselves observable,
and react to changes to any of their dependencies on their own.

```Swift
class ProjectSummaryViewModel {
    let currentDocument: Variable<Document> = ...
    let currentAccount: Variable<Account?> = ...
    
    let project: Variable<Project> = ...
    
    /// The name of the current project.
	var projectName: Updatable<String> { 
	    return project.map { $0.name } 
	}
	
    /// The number of issues (open and closed) in the current project.
	var isssueCount: AnyObservableValue<Int> { 
	    return project.selectCount { $0.issues }
	}
	
    /// The number of open issues in the current project.
	var openIssueCount: AnyObservableValue<Int> { 
	    return project.selectCount({ $0.issues }, filteredBy: { $0.isOpen })
	}
	
    /// The ratio of open issues to all issues, in percentage points.
    var percentageOfOpenIssues: AnyObservableValue<Int> {
        // You can use the standard arithmetic operators to combine observables.
    	return AnyObservableValue.constant(100) * openIssueCount / issueCount
    }
    
    /// The number of open issues assigned to the current account.
    var yourOpenIssues: AnyObservableValue<Int> {
        return project
            .selectCount({ $0.issues }, 
                filteredBy: { $0.isOpen && $0.owner == self.currentAccount })
    }
    
    /// The five most recently created issues assigned to the current account.
    var yourFiveMostRecentIssues: AnyObservableValue<[Issue]> {
        return project
            .selectFirstN(5, { $0.issues }, 
                filteredBy: { $0.isOpen && $0.owner == currentAccount }),
                orderBy: { $0.created < $1.created })
    }

    /// An observable version of NSLocale.currentLocale().
    var currentLocale: AnyObservableValue<NSLocale> {
        let center = NSNotificationCenter.defaultCenter()
		let localeSource = center
		    .source(forName: NSCurrentLocaleDidChangeNotification)
		    .map { _ in NSLocale.currentLocale() }
        return AnyObservableValue(getter: { NSLocale.currentLocale() }, futureValues: localeSource)
    }
    
    /// An observable localized string.
    var localizedIssueCountFormat: AnyObservableValue<String> {
        return currentLocale.map { _ in 
            return NSLocalizedString("%1$d of %2$d issues open (%3$d%%)",
                comment: "Summary of open issues in a project")
        }
    }
    
    /// An observable text for a label.
    var localizedIssueCountString: AnyObservableValue<String> {
        return AnyObservableValue
            // Create an observable of tuples containing values of four observables
            .combine(localizedIssueCountFormat, issueCount, openIssueCount, percentageOfOpenIssues)
            // Then convert each tuple into a single localized string
            .map { format, all, open, percent in 
                return String(format: format, open, all, percent)
            }
    }
}
```

(Note that some of the operations above aren't implemented yet. Stay tuned!)

Whenever the model is updated or another project or account is selected, the affected `Observable`s 
in the view model are recalculated accordingly, and their subscribers are notified with the updated
values. 
GlueKit does this in a surprisingly efficient manner---for example, closing an issue in
a project will simply decrement a counter inside `openIssueCount`; it won't recalculate the issue
count from scratch. (Obviously, if the user switches to a new project, that change will trigger a recalculation of that project's issue counts from scratch.) Observables aren't actually calculating anything until and unless they have subscribers.

Once you have this view model, the view controller can simply connect its observables to various
labels displayed in the view hierarchy:

```Swift
class ProjectSummaryViewController: UIViewController {
    private let visibleConnections = Connector()
    let viewModel: ProjectSummaryViewModel
    
    // ...
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
	    viewModel.projectName.values
	        .connect { name in
	            self.titleLabel.text = name
	        }
	        .putInto(visibleConnections)
	     
	    viewModel.localizedIssueCountString.values
	        .connect { text in
	            self.subtitleLabel.text = text
	        }
	        .putInto(visibleConnections)
	        
        // etc. for the rest of the observables in the view model
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        visibleConnections.disconnect()
    }
}
```

Setting up the connections in `viewWillAppear` ensures that the view model's complex observer
combinations are kept up to date only while the project summary is displayed on screen.

The `projectName` property in `ProjectSummaryViewModel` is declared an `Updatable`, so you can 
modify its value. Doing that updates the name of the current project: 

```Swift
viewModel.projectName.value = "GlueKit"   // Sets the current project's name via a key path
print(viewModel.project.name.value)       // Prints "GlueKit"
```


