# GlueKit

A Swift framework for 
[reactive programming](https://en.wikipedia.org/wiki/Reactive_programming)
that lets you create observable values and connect them up in interesting and useful ways.
It is called GlueKit because it lets you stick stuff together. 

GlueKit contains type-safe analogues for Cocoa's 
[Key-Value Coding](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/KeyValueCoding/Articles/Overview.html) 
and 
[Key-Value Observing](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/KeyValueObserving/KeyValueObserving.html)
subsystems, written in pure Swift.
Besides providing the basic observation mechanism, it also supports full-blown *key path*
observing, where you're observing a value that's not directly available, but can be looked up
via a sequence of nested observables, some of which may represent one-to-one or one-to-many
relationships between model objects. 

GlueKit will also provide a rich set of observable combinators
as a more flexible and extensible Swift version of KVC's 
[collection operators](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/KeyValueCoding/Articles/CollectionOperators.html). (These are being actively developed.)

GlueKit does not rely on the Objective-C runtime for its basic functionality, but on Apple platforms
it does provide easy-to-use adapters for observing KVO-compatible key paths on NSObjects and 
NSNotificationCenter notifications.

A major design goal for GlueKit is to eventually serve as the underlying observer implementation
for a future model object graph (and perhaps persistence) project, which would include a 

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
    let owner: Variable<Account?>
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


Given this model, you can set up a view model for a project summary screen that displays various
useful data about the currently selected project:

```Swift
class ProjectSummaryViewModel {
    let currentDocument: Variable<Document> = ...
    let currentAccount: Variable<Account?> = ...
    
    let project: Variable<Project> = ...
    
    /// The name of the current project.
	var projectName: Updatable<String> { 
	    return project.select { $0.name } 
	}
	
    /// The number of issues (open and closed) in the current project.
	var isssueCount: Observable<Int> { 
	    return project.selectCount { $0.issues }
	}
	
    /// The number of open issues in the current project.
	var openIssueCount: Observable<Int> { 
	    return project.selectCount({ $0.issues }, where: { $0.isOpen })
	}
	
    /// The ratio of open issues to all issues, in percentage points.
    var percentageOfOpenIssues: Observable<Int> {
        // You can use the standard arithmetic operators to combine observables.
    	return Observable.constant(100) * openIssueCount / issueCount
    }
    
    /// The number of open issues assigned to the current account.
    var yourOpenIssues: Observable<Int> {
        return project
            .selectCount(
                { $0.issues }, 
                where: { $0.isOpen && $0.owner == self.currentAccount })
    }
    
    /// The five most recently created issues assigned to the current account.
    var yourFiveMostRecentIssues: Observable<[Issue]> {
        return project
            .selectFirstN(5, { $0.issues }, 
                where: { $0.isOpen && $0.owner == currentAccount }),
                orderBy: { $0.created < $1.created })
    }

    /// An observable version of NSLocale.currentLocale().
    var currentLocale: Observable<NSLocale> {
        let center = NSNotificationCenter.defaultCenter()
		let localeSource = center
		    .sourceForNotification(NSCurrentLocaleDidChangeNotification)
		    .map { _ in NSLocale.currentLocale() }
        return Observable(getter: { NSLocale.currentLocale() }, futureValues: localeSource)
    }
    
    /// An observable localized string.
    var localizedIssueCountFormat: Observable<String> {
        return currentLocale.map { _ in 
            return NSLocalizedString("%1$d of %2$d issues open (%3$d%%)",
                comment: "Summary of open issues in a project")
        }
    }
    
    /// An observable text for a label.
    var localizedIssueCountString: Observable<String> {
        return Observable
            // Create an observable of tuples containing values of three observables
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

```

Setting up the connections in `viewWillAppear` ensures that the view model's complex observer
combinations are kept up to date only while the project summary is displayed on screen.

The `projectName` property in `ProjectSummaryViewModel` is declared an `Updatable`, so you can 
modify its value. Doing that updates the name of the current project: 

```Swift
viewModel.projectName.value = "GlueKit"   // Sets the current project's name via a key path
print(viewModel.project.name.value)       // Prints "GlueKit"
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

