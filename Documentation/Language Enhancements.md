# Potential Swift Improvements That Would Help GlueKit

This document lists a couple of potential improvements to the Swift language and compiler that would simplify the design/implementation of GlueKit.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [Property Behaviors ([SE-0030])](#property-behaviors-se-0030)
- [More Complete Support for Generics](#more-complete-support-for-generics)
  - [Generalized Protocol Existentials](#generalized-protocol-existentials)
  - [Permitting `where` clauses to constrain associated types ([SE-0142])](#permitting-where-clauses-to-constrain-associated-types-se-0142)
  - [Conditional Conformances ([SE-0143])](#conditional-conformances-se-0143)
  - [Nested generics](#nested-generics)
  - [Allowing subclasses to override requirements satisfied by defaults](#allowing-subclasses-to-override-requirements-satisfied-by-defaults)
- [Abstract Methods](#abstract-methods)
- [Relaxed Superclass Visibility Requirements](#relaxed-superclass-visibility-requirements)
- [Closure Contexts With Inline Storage (Related issue: [SR-3106])](#closure-contexts-with-inline-storage-related-issue-sr-3106)
- [Assorted Bugfixes](#assorted-bugfixes)
  - [Generic subclass cannot override methos in non-generic superclass, and vice versa ([SR-2427])](#generic-subclass-cannot-override-methos-in-non-generic-superclass-and-vice-versa-sr-2427)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->


## Property Behaviors ([SE-0030])

> There are property implementation patterns that come up repeatedly. Rather than hardcode a fixed set of patterns into the compiler, we should provide a general "property behavior" mechanism to allow these patterns to be defined as libraries. -- [SE-0030]


To declare observable properties in GlueKit, you currently need to declare them with a  `Variable` type, and you have to access their values through an inconvenient `value` property:

```swift
class Book {
    let title: Variable<String>
    let pageCount: Variable<Int>
}

let book: Book = ...
book.title.value = "The Colour of Magic"
let c = book.pageCount.futureValues.subscribe { print("Page count is now \($0)" }
```

It is possible to make this a little less painful by judicious use of computed properties:

```swift
class Book {
	let observableTitle: Variable<String>
    var title: String {
        get { return observableTitle.value }
        set { observableTitle.value = newValue }
    }
    
    let observablePageCount: Variable<Int>
    var pageCount: Int {
        get { return observablePageCount.value }
        set { observablePageCount.value = newValue }
    }
}

let book: Book = ...
book.title = "The Colour of Magic"
let c = book.observablePageCount.futureValues.subscribe { print("Page count is now \($0)" }
```

This makes usage of these properties nicer, but it adds extra boilerplate to the definition of your model classes.

If the [proposal for Property Behaviors][SE-0030] would be implemented, we could
eliminate this boilerplate and have observable properties that approach (or arguably even exceed) the readability of Cocoa:

```swift
class Book {
	var [observable] title: String
    var [observable] pageCount: Int
}

let book: Book = ...
book.title = "The Colour of Magic"
let c = book.pageCount.[observable].subscribe { print("Page count is now \($0)" }
```

Property Behaviors also allow storage for the Signals associated with these 
variables to be embedded directly in the `Book` class, instead of being allocated separately. (Each such observable variable needs to count open transactions and keep track of subscribed observers somehow.)


[SE-0030]: https://github.com/apple/swift-evolution/blob/master/proposals/0030-property-behavior-decls.md


## More Complete Support for Generics

GlueKit heavily relies on Swift's generic types and protocols with associated values. Any and all 
language improvements relating to these concepts would find immediate use in GlueKit.
For example, the implementation of pretty much any item in the [Generics Manifesto][gm] 
would have immediate impact on GlueKit. (Some of these are explicitly mentioned below.)

[gm]: https://github.com/apple/swift/blob/master/docs/GenericsManifesto.md

GlueKit was designed with the assumption that most items in the Generic Manifesto will be implemented at some point. I sometimes chose a less convenient way 
to express things so that when/if a particular item on this list gets implemented, GlueKit will find itself immediately
at home in the new language, with minimal design changes.


### Generalized Protocol Existentials

> The restrictions on existential types came from an implementation limitation, but it is reasonable to allow a value of protocol type even when the protocol has Self constraints or associated types. -- [GenericsManifesto.md][gm-generalized-existentials]

[gm-generalized-existentials]: https://github.com/apple/swift/blob/master/docs/GenericsManifesto.md#generalized-existentials
 
GlueKit is largely about the exploration of possible interactions between a handful of concepts, all which are 
captured by protocols with associated types: `SourceType`, `SinkType`, `ObservableType`, `UpdatableType`,
`ObservableValueType`, `ObservableArrayType`, `UpdatableSetType`, etc.

The language does not provide existentials for these protocols -- so type erasure needs to be implemented manually.
This leads to the proliferation of the various `Any*` types -- see `AnySource`, `AnySink`, `AnyObservableValue`,
`AnyUpdatableValue`, `AnyObservableArray`, `AnyUpdatableSetType`, etc. These are all implemented manually, 
using subclass polymorphism.

Sometimes the need for type erasure can be eliminated by expanding the public API surface. For example, wherever 
an `Any*` type is used as a return value, we could substitute the (currently private/internal) concrete type instead.
There are good reasons to do this whether or not we get generalized existentials: having transformation methods
return concrete types enables static method dispatch. It might be worthwhile to do this for at least some of the 
transformations.
(The class names and their exposed API surface need to be carefully reviewed and updated, though.)
Concrete return types do make life a little more difficult for users, though: they will have to explicitly 
specify the type in, say, a property declaration.

However, the need for `Any*` cannot be entirely eliminated. For example, `Signal` needs to be able to store its
subscribers in a collection, which is only possible with some form of type erasure. (The current `Source` API
also needs `Signal` to be able to reify type-erased values, getting the original type back. This is similar to [opening a generalized existential][gm-open].)

Doing type erasure by subclass polymorphism implies that GlueKit's `Any*` types always need to heap-allocate a box. On the other hand, Swift's protocol existentials include some space to store small value types inline, which makes them work without allocation in a lot of cases. This optimization is hard (even impossible?) to emulate in Swift code, but it would be very much desirable to have it for e.g. `AnySink`.

[gm-open]: https://github.com/apple/swift/blob/master/docs/GenericsManifesto.md#opening-existentials

### Permitting `where` clauses to constrain associated types ([SE-0142])

> This proposal seeks to introduce a where clause to associated type declarations and improvements to protocol constraints to bring associated types the same expressive power as generic type parameters. -- [SE-0142]

[SE-0142]: https://github.com/apple/swift-evolution/blob/master/proposals/0142-associated-types-constraints.md

This is a biggie! Not having the ability to specify that e.g. an `ObservableArrayType` must have
`Change == ArrayChange<Element>` means that this constraint has to be explicitly specified by almost every consumer
of an observable array. I currently have ~300 such explicit constraints in the source code, making working on GlueKit an exercise in patience.

The proposal to implement this improvement has been accepted, so presumably it'll get implemented relatively soon.

Meanwhile, we can mostly work around the issue by having the child protocol include
property requirements that specialize on the requirements of the parent:

```swift
 protocol ObservableType { // Not the real definition
     associatedtype Change: ChangeType 
 
     var value: Change.Value { get }
     var changes: AnySource<Change> { get }
 }

 protocol ObservableArrayType {
     associatedtype Element: Hashable  

     var value: [Element] { get }
     var changes: AnySource<ArrayChange<Element>> { get }
 }
```

In most (maybe all) contexts, the type inference engine sees that `changes` in
`ObservableArrayType` refines the similar requirement in `ObservableType` 
and concludes that `Change` can only be an `ArrayChange` there. In the current
codebase, `ObservableType` doesn't have a property requirement in like `changes` 
above -- the update source is implemented by two methods. However, it would be 
easy enough to define a dummy property that is never actually used.


### Conditional Conformances ([SE-0143])

> Conditional conformances express the notion that a generic type will conform to a particular protocol only when its type arguments meet certain requirements." -- [SE-0143]

This is a popular Swift feature request that seems to be on track for implementation.

[SE-0143]: https://github.com/apple/swift-evolution/blob/master/proposals/0143-conditional-conformances.md

At first glance, it looks like conditional conformances might allow us to express deep relationships between our 
concepts: for example, we might want to say that an `ObservableType` whose `Change` is an `ArrayChange` is
automatically an `ObservableArrayType`. But that's not the case:

1. The proposal allows conditional conformances for generic types only, not protocols. It enables us to specify that
   `Array` should implement `Equatable` when its elements do, but we won't be able to do the same for `Collection`.

2. Even if we could do that, an `ObservableArrayType` is more than just an observable whose delta type matches 
   a specific structure; it also defines a more efficient API for array access. Without this, we lose what makes 
   observable arrays (reasonably) efficient.

Conditional conformances will, however, help a great deal with small annoying details -- for example, we could say that a `Variable` with an integer value automatically implements `ExpressibleByIntegerLiteral`, eliminating the need 
for `IntVariable`. We could have `ValueChange`, `SetChange` and `ArrayChange` explicitly implement `Equatable`, 
which would help unit tests.

### Nested generics

> There isn't much to say about this: the compiler simply needs to be improved to handle nested generics throughout. -- [GenericsManifesto.md][gm-nested-generics]

[gm-nested-generics]: https://github.com/apple/swift/blob/master/docs/GenericsManifesto.md#nested-generics

Currently Swift does not support declaring nested types in generics, which means some helper types (like method forwarding structs that implement `SinkType`) need to be declared outside the generic struct/class. This means the type parameters of the parent generic and (most annoyingly) the constraints of these parameters need to be repeated on every such helper type. Assuming types nested in generics would implicitly inherit the type parameters of their parents, nested generics would eliminate such boring repetitions.

### Allowing subclasses to override requirements satisfied by defaults

> When a superclass conforms to a protocol and has one of the protocol's requirements satisfied by a member of a protocol extension, that member currently cannot be overridden by a subclass. -- [GenericsManifesto.md][gm-overriding-extensions]

[gm-overriding-extensions]: https://github.com/apple/swift/blob/master/docs/GenericsManifesto.md#allowing-subclasses-to-override-requirements-satisfied-by-defaults-

For each protocol requirement that has a default implementation in a protocol extension, we currently need to duplicate that implementation in the (abstract) base class that is used to implement boxing for type erasure. This is error-prone and ugly.

## Abstract Methods

There is currently no way to mark an overridable member as abstract in Swift. I've not seen proposals to add support for this, but it seems obvious Swift needs this -- abstract classes and members are an important part of OOP. Without the help of the compiler, it is all too easy to forget a required method override.

Protocols supply an alternative, often better, way to express the things we used to model with abstract methods. But in some contexts (particularly when implementing type-erasure for protocols with associated types), abstract methods are still useful.
(Obviously, generalized existentials would remove this usecase.)

## Relaxed Superclass Visibility Requirements

Swift currently requires the superclasses of public classes to be also exposed as public, even if they're just an implementation detail. This is why GlueKit exposes some underscored classes like `_BaseObservableArray` in its public interface.

This restriction is not consistently enforced by the compiler, but breaking it can lead to misleading errors and/or strange behavior at runtime. (I can't remember which.)

## Closure Contexts With Inline Storage (Related issue: [SR-3106])

[SR-3106]: https://bugs.swift.org/browse/SR-3106

In the current version of Swift, a variable of a function type has storage for just two machine words, which is enough to hold function pointer and a single-word context containing the values captured by the closure.

This means that the context of most escaping closures needs to be heap-allocated, even if they capture only a couple of constants. The compiler may be able to optimize away the allocation if the closure is non-escaping, but if we need to store the closure for later execution, the context needs to be on the heap.

Closures that capture only a single-word constant may at some point store that value directly in the context word. This isn't currently implemented, though. (Note that the captured value may or may not need to be reference counted. `self` is refcounted, but a captured `Float` wouldn't be. Some bits need to be reserved somewhere to keep track of this.)

Swift's partially applied methods are closures that capture `self`. It would be possible to special-case them such that the `self` reference is stored directly in context word; but this is not currently implemented. So partially applied methods always incur the cost of a heap allocation when used in escaping contexts. This makes them slower than representing the method call with a forwarding struct like this:

```swift
class Foo {
	func greet(_ name: String) {
		print("Hello, \(name)!")
	}
}

struct FooForwarder {
	let foo: Foo
	func apply(_ name: String) {
		foo.greet(name)
	}
}

let foo = Foo()
let greeter1 = FooForwarder(foo)
let greeter2 = foo.greet
```

Creating `greeter1` is measurably faster than creating `greeter2`, because the latter needs to do an allocation.
This is the primary reason why GlueKit defines the `SinkType` protocol instead of just defining a typealias for a function type.
(The other reason is that it is useful to be able to add extra requirements (i.e., `Hashable`) and extensions to sinks. But we could live without those!)

If the size of function types would be widened to include space for more bits of context, lots of simple closures would fit inline, without the need for context allocation. There is precedent for this with `Any`, which currently includes space for inline storage of data up to three words in size.

Aggregate observation in GlueKit (e.g., `ArrayMappingForValueField`) needs to register observer sinks that capture two refcounted pointers -- one for the `self` pointer of the aggregate observable itself, the other for keeping track of the particular element that is the source of the change. If these would be represented by closures, then they would be heap-allocated, making them much more expensive -- unless Swift's function types would be widened & the inline storage optimization was implemented. 

(We could leave some of the captures uncaptured and store them alongside the closure, but it seems easier to just define a forwarding struct -- which achieves exactly the same thing.)


## Assorted Bugfixes

This section lists compiler bugs that have a direct effect on GlueKit.

### Generic subclass cannot override methos in non-generic superclass, and vice versa ([SR-2427])

This compiler bug affects the design of `TimerSource`. To work around it, I had to add a dummy unusued type parameter to it, 
and define a typealias to paper over the ugliness.

[SR-2427]: https://bugs.swift.org/browse/SR-2427

This bug [has been fixed][PR-5424] on Swift's master branch.

[PR-5424]: https://github.com/apple/swift/pull/5424
