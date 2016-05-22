# Memory Management

Note that in the [first example in the README](https://bustoutsolutions.github.io/siesta/#basic-usage), no code calls any sort of “removeObserver” method. Siesta can automatically remove observers when they are no longer needed by tying them to the lifecycles of other objects.

Siesta achieves this by introducing a notion of **observer ownership,** which ties an observer to the lifecycle of some object. Here’s how this mechanism plays out in a few common cases:

## Self-Owned Observer

An observer can register as its own owner using the single-argument flavor of `addObserver()`. This essentially means, “Someone else owns this observer object. Keep only a weak reference to it. Send it notifications until it is deallocated.”

This is the right approach to use with an object implementing `ResourceObserver` that already has a parent object — for example, a `UIView` or `UIViewController`:

```swift
class ProfileViewController: UIViewController, ResourceObserver {
        
    override func viewDidLoad() {
        …
        someResource.addObserver(self)
    }
}
```

## Observer with an External Owner

An observer can also register with `addObserver(observer:, owner:)`. This means, “This observer’s only purpose is to be an observer. Keep a strong reference and send it notifications until it its _owner_ is deallocated.”

This is the right approach to use with little glue objects that implement `ResourceObserver`:

```swift
someResource.addObserver(MyLittleGlueObject(), owner: self)
```

This is also the approach you _must_ use when registering structs and closures as observers:

```swift
someResource.addObserver(owner: someViewController) {
    resource, event in
    print("Received \(event) for \(resource)")
}
```

In the code above, the print statement will continue logging until `someViewController` is deallocated.

## Manually Removing Observers

Sometimes you’ll want to remove an observer explicitly, usually because you want to point the same observer at a different resource.

A common idiom is for a view controller to have a settable property for the resource it should show:

```swift
var displayedResource: Resource? {
    didSet {
        // This removes both the observers added below,
        // because they are both owned by self.
        oldValue?.removeObservers(ownedBy: self)

        displayedResource?
            .addObserver(self)
            .addObserver(owner: self) { resource, event in … }
            .loadIfNeeded()
    }
}
```

## Detailed Ownership Rules

Observers have owners.

* An observer’s observation of a resource is contingent upon one or more owners.
* Owners can be any kind of object.
* An observer may be its own owner.

Ownership affects the observer lifecycle.

* A resource keeps a strong reference to an observer as long as the observer has owners other than itself.
* An observer stops observing a resource as soon as all of its owners have either been deallocated or explicitly removed.

Observers affect the resource lifecycle.

* A resource is eligible for deallocation if and only if it has no observers _and_ there are no other strong references to it from outside the Siesta framework.
* Eligible resources are only deallocated if there is memory pressure.
* At any time, there exists at _most_ one `Resource` instance per `Service` for a given URL.

These rules, while tricky when all spelled out, make the right thing the easy thing most of the time.
