# Siesta

iOS REST Client Framework

**TL;DR**: Drastically simplifies app code by providing a client-side cache of observable models for RESTful resources.

* **OS:** iOS 8+
* **Languages:** Written in Swift, supports Swift and Objective-C
* **Build requirements:** Xcode 7 beta, Swift 2.0, Carthage
* **License:** MIT
* **Status:** Alpha, in active development. Works well, but API still in flux. Seeking feedback. Please experiment!


<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [What’s It For?](#what%E2%80%99s-it-for)
  - [The Problem](#the-problem)
  - [The Solution](#the-solution)
- [Design Philosophy](#design-philosophy)
- [Features](#features)
- [Installation](#installation)
  - [Carthage](#carthage)
  - [CocoaPods](#cocoapods)
- [Usage](#usage)
  - [Services and Resources](#services-and-resources)
  - [Requests](#requests)
  - [Resource State](#resource-state)
  - [Observers](#observers)
  - [UI Components](#ui-components)
  - [Memory Management](#memory-management)
  - [Logging](#logging)
- [Examples](#examples)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->


## What’s It For?

### The Problem

Want your app to talk to an API? Welcome to your state nightmare!

You need to display response data whenever it arrives, unless the requesting ViewController is no longer visible, unless some other currently visible ViewController happens to want the same data. You should show a loading indicator, display user-friendly errors (but no modal alert dogpiles!), give users a retry mechanism, and hide all that when a subsequent request succeeds. Be sure to avoid redundant requests. Oh, and remember not to retain your ViewController by accident in your callback closures.

What could possibly go wrong?

### The Solution

Siesta ends this headache by providing an observable model of a RESTful resource’s state. The model answers three basic questions:

* What is the latest data for this resource, if any?
* Did the latest request result in an error?
* Is there a request in progress?

…then provides notifications whenever the answers to these questions change.

Siesta handles all the transitions and corner cases to deliver these answers wrapped up with a pretty bow on top, letting you focus on your UI.

## Design Philosophy

Make the default thing the right thing most of the time.

Make the right thing easy all of the time.

Build from need. Don’t invent solutions in search of problems.

Design the API with these goals:

1. Make client code easy to **read**.
2. Make client code easy to **write**.
3. Keep the API clean.
4. Keep the implementation tidy.

_…in that order of priority._

## Features

- [x] Decouples UI state from network request state
- [x] Observer model eliminates complex, error-prone state tracking logic
- [x] Eliminates redundant network requests
- [x] Caches data across multiple ViewControllers
- [x] Unified reporting for all errors: encoding, network, server-side, and parsing
- [x] Transparent Etag / If-Modified-Since handling
- [x] Painless handling for JSON and plain text
- [x] Customizable response transformation
- [x] Prebaked UI for loading & error handling
- [x] Uses Alamofire for networking by default; injectable transport providers if you want to use other network libraries
- [x] Thorough regression testing
- [x] Debug-friendly, customizable logging
- [x] Written in Swift with a great Swift-centric API, but…
- [x] …also works great from Objective-C thanks to a compatibility layer

**Forthcoming:**

- [ ] Graceful handling for authenticated sessions
- [ ] Intelligent progress reporting that accounts for request, latency, and response
- [ ] Customizable data caching

**If users express sufficient interest:**

- [ ] Built-in parsing for other common types, e.g. XML
- [ ] Optimistic local data updating with rollback to better support POST/PUT/PATCH
- [ ] Prebaked progress bar UI component

## Installation

We recommend adding Siesta to your project using either Carthage or Cocoapods. You can also manually build the framework yourself.

### Carthage

[Install Carthage](https://github.com/Carthage/Carthage#installing-carthage).

Siesta requires Swift 2.0, so install the latest [Xcode 7 beta](https://developer.apple.com/xcode/downloads/), and point the command line tools at it:

    sudo xcode-select -s /Applications/Xcode-beta.app/Contents/Developer

Create a `Cartfile` in the root of your project if it don’t already exist, and add:

    github "bustoutsolutions/siesta" "master"

(Adding `master` keeps you on the bleeding edge, which is necessary until Siesta has an official release.)

Follow the [Carthage instructions](https://github.com/Carthage/Carthage#adding-frameworks-to-an-application) to add `Siesta.framework` to your project.

As of this writing, there is one additional step you need to follow for Xcode 7 beta that isn’t in the Carthage docs:

* Build settings → Framework search paths → `$(PROJECT_DIR)/Carthage/Build/iOS/`

(In-depth discussion of Carthage on XC7 is [here](https://github.com/Carthage/Carthage/issues/536).)

### CocoaPods

Will add support when Xcode 7 goes out of beta. (Pull request welcome!)

## Usage

### Services and Resources

Create a `Service` singleton for each API your app uses:

```swift
import Siesta

class MyAPI: Service {
    static let instance = MyAPI(base: "https://api.example.com")
}
```

Your service subclass must be written in Swift. You can use it from both Objective-C and Swift code.

Retrieve `Resource` objects from the service:

```swift
MyAPI.instance.resource("/profile")
MyAPI.instance.resource("/items").child("123").child("related")
MyAPI.instance.resource("/items/123/related") // same as previous
```
```objc
[MyAPI.instance resource:@"/profile"];
[[[MyAPI.instance resource:@"/items"] child:@"123"] child:@"related"];
[MyAPI.instance resource:@"/items/123/related"]; // same as previous
```

Within the context of a `Service`, there is at most one `Resource` object for a given URL, no matter how you navigate to that URL.

You may add convenience accessors to your service for commonly used resources:

```swift
class MyAPI: Service {
    static let instance = MyAPI(base: "https://api.example.com")

    var profile: Resource { return resource("profile") }
}
```

### Requests

Resources start out empty — no data, no error, not loading. To trigger a GET request:

```swift
MyAPI.instance.profile.loadIfNeeded()
```
```objc
[MyAPI.instance.profile loadIfNeeded];
```

Don’t worry about calling `loadIfNeeded()` too often. Call it in your `viewWillAppear()`! Call it in response to touch events! Call it 50 times a second! It automatically suppresses redundant requests. (Data expiration time is configurable on a per-service and per-resource level.)

To force a network request, use `load()`:

```swift
MyAPI.instance.profile.load()
```

To update a resource with a POST/PUT/PATCH, use `request()`:

```swift
MyAPI.instance.profile.request(.POST, json: ["foo": [1,2,3]])
MyAPI.instance.profile.request(.POST, urlEncoded: ["foo": "bar"])
MyAPI.instance.profile.request(.POST, text: "Many years later, in front of the terminal...")
MyAPI.instance.profile.request(.POST, data: nsdata)
```

See notes below on [request() vs. load()](#request-vs-load).

### Resource State

A resource keeps a local cache of the latest valid data:

```swift
resource.data       // Gives a string, dict/array (for JSON), NSData, or
                    // nil if no data is available. You can also configure
                    // custom data types (e.g. model objects).

resource.text       // Typed accessors return an empty string/dict/array
resource.dict       // if data is either unavailable or not of the expected
resource.array      // type. This reduces futzing with optionals.

resource.latestData // Full metadata, in case you need the gory details.
```

A resource knows whether it is currently loading, which lets you show/hide a spinner or progress bar:

```swift
resource.loading  // True if network request in progress
```

…and it knows whether the last request resulted in an error:

```swift
resource.latestError               // Present if latest load attempt failed
resource.latestError?.userMessage  // String suitable for display in UI
```

That `latestError` rolls up many different kinds of error — transport-level errors, HTTP errors, and client-side parse errors — into a single consistent structure that’s easy to wrap in a UI.

#### Resource State is Multifaceted

Note that data, error, and loading are not mutually exclusive. For example, consider the following scenario:

* You load a resource, and the request succeeds.
* You refresh it later, and that second request fails.
* You initiate a third request.

At this point, `loading` is true, `latestError` holds information about the previously failed request, and `data` still gives the old cached data.

Siesta’s opinion is that your UI should decide for itself which of these things it prioritizes over the others. For example, you may prefer to refresh silently when there is already data available, or you may prefer to always show a spinner.

#### Request vs. Load

The `load()` and `loadIfNeeded()` methods update the resource’s state and notify observers when they receive a response. The various forms of the `request()` method, however, do not; it is up to you to say what effect if any your request had on the resource’s state.

When you call `load()`, which is by default a GET request, you expect the server to return the full state of the resource. Siesta will cache that state and tell the world to display it.

When you call `request()`, however, you don’t necessarily expect the server to give you the full resource back. You might be making a POST request, and the server will simply say “OK” — perhaps by returning 200 and an empty response body. In this situation, it’s up to you to update the resource state.

One way to do this is to trigger a load on the heels of a successful POST/PUT/PATCH:

```swift
resource.request(.PUT, json: newState).success() {
    _ in resource.load()
}
```

…or perhaps a POST request gives you the location of a new resource in a header:

```swift
resource.request(.POST, json: newState).success() {
    let createdResource = resource.relative($0.header("Location")))
    …
}
```

* TODO: document local update using response data

### Observers

UI components can observe changes to a resource, either by implementing the `ResourceObserver` protocol (or its counterpart `ResourceObserverObjc` in Objective-C):

```swift
resource.addObserver(self)
```
```objc
[resource addObserver:self];
```

…or by providing a callback closure (Swift only):

```swift
resource.addObserver(owner: self) {
    resource, event in
    …
}
```

Observers receive a notification when a resource starts loading, receives new data, or receives an error. Each observer is also pinged immediately when it first starts observing, even if the resource has not changed. This lets you put all your UI-populating code in one place.

The simplest way to implement your observer is to ignore the triggering event, and take an idempotent “update everything” approach:

```swift
func resourceChanged(resource: Resource, event: ResourceEvent) {
    // The convenience .dict accessor returns empty dict if no data,
    // so the same code can both populate and clear fields.
    let json = JSON(resource.dict)
    nameLabel.text = json["name"].string
    favoriteColorLabel.text = json["favoriteColor"].string

    if resource.loading {
        activityIndicator.startAnimating()
    } else {
        activityIndicator.stopAnimating()
    }

    errorLabel.text = resource.latestError?.userMessage
}
```

Note the pleasantly reactive flavor this code takes on — without the overhead of adopting full-on Reactive programming with captial R.

If updating the whole UI is an expensive operation (but it rarely is; benchmark first!), you can use the `event` parameter and the metadata in `latestData` and `latestError` to fine-tune your UI updates.

Note that you can also attach callbacks to an individual request, in the manner of more familiar HTTP frameworks:

```swift
resource.load()
    .success { data in print("Wow! Data!") }
    .failure { error in print("Oh, bummer.") }
```

These _response callbacks_ are one-offs, called at most once when a request completes and then discarded. Siesta’s important distinguishing feature is that an _observer_ will keep receiving notifications about a resource, no matter who requests it, no matter when the responses arrive.

Putting it all together:

```swift
import Siesta
import SwiftyJSON

class ProfileViewController: UIViewController, ResourceObserver {
    @IBOutlet weak var nameLabel, favoriteColorLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var errorLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        MyAPI.instance.profile.addObserver(self)
    }

    override func viewWillAppear(animated: Bool) {
        MyAPI.instance.profile.loadIfNeeded()
    }

    func resourceChanged(resource: Resource, event: ResourceEvent) {
        let json = JSON(resource.dict)
        nameLabel.text = json["name"].string
        favoriteColorLabel.text = json["favoriteColor"].string

        if resource.loading {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }

        errorLabel.text = resource.latestError?.userMessage
    }
}
```

### UI Components

The code above is already easy — but the business of showing the activity indicator and error message can get repetitive. Siesta provides a status overlay view that takes care of that for you.

The overlay is designed to cover your entire content view when there is an error, by you can position it as you like. It comes with a tidy standard layout:

<p align="center"><img alt="Standard error overlay view" src="Docs/images/standard-error-overlay@2x.png" width=320 height=136></p>

…and you can also provide your own custom .xib.

Using the standard overlay, the example above becomes:

```swift
class ProfileViewController: UIViewController, ResourceObserver {
    @IBOutlet weak var nameLabel, favoriteColorLabel: UILabel!
    
    let statusOverlay = ResourceStatusOverlay()

    override func viewDidLoad() {
        super.viewDidLoad()

        statusOverlay.embedIn(self)

        MyAPI.instance.profile
            .addObserver(self)
            .addObserver(statusOverlay)
    }

    override func viewDidLayoutSubviews() {
        statusOverlay.positionToCoverParent()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        MyAPI.instance.profile.loadIfNeeded()
    }

    func resourceChanged(resource: Resource, event: ResourceEvent) {
        let json = JSON(resource.dict)
        nameLabel.text = json["name"].string
        favoriteColorLabel.text = json["favoriteColor"].string
    }
}
```

Or in Objective-C:

```objc
@interface ProfileViewController: UIViewController <BOSResourceObserver>
@property (weak,nonatomic) IBOutlet UILabel *nameLabel, *favoriteColorLabel;
@property (strong,nonatomic) BOSResourceStatusOverlay *statusOverlay;
@end

@implementation ProfileViewController

- (void) viewDidLoad {
    super.viewDidLoad()

    self.statusOverlay = [[[BOSResourceStatusOverlay alloc] init] embedIn:self];

    [[MyAPI.instance.profile
        addObserver:self]
        addObserver:statusOverlay];
}

- (void) viewDidLayoutSubviews {
    [_statusOverlay positionToCoverParent];
}

- (void) viewWillAppear: (BOOL) animated {
    [super viewWillAppear:animated];    
    [MyAPI.instance.profile loadIfNeeded];
}

- (void) resourceChanged: (BOSResource*) resource event: (NSString*) event {
    id json = resource.dict;
    nameLabel.text = json[@"name"];
    favoriteColorLabel.text = json[@"favoriteColor"];
}

@end
```

Note that this small amount of code is a fully armed and operational REST-backed UI.

### Memory Management

Note that in the examples above, no code calls any sort of “removeObserver” method. Siesta automatically removes observers when they are no longer needed.

Siesta achieves this by introducing a notion of **observer ownership,** which ties an observer to the life cycle of an object. Here’s how this mechanism plays out in a few common cases:

#### Self-Owned Observer

An observer can register as its own owner using the single-argument flavor of `addObserver()`. This essentialy means, “Someone else owns this observer object. Keep only a weak reference to it. Send it notifications until it is deallocated.”

This is the right approach to use with an object implementing `ResourceObserver` that already has a parent object — for example, a `UIView` or `UIViewController`:

```swift
class ProfileViewController: UIViewController, ResourceObserver {
        
    override func viewDidLoad() {
        …
        someResource.addObserver(self)
    }
}
```

#### Observer with an External Owner

An observer can also regiser with `addObserver(observer:, owner:)`. This means, “This observer’s only purpose is to be an observer. Keep a strong reference and send it notifications until it its _owner_ is deallocated.”

This is the right approach to use with little glue objects that implement `ResourceObserver`. It is also the approach you _must_ use when registering structs and closures as observers:

```swift
someResource.addObserver(someViewController) {
    resource, event in
    print("Received \(event) for \(resource)")
}
```

In the code about, the print statement will continue logging until `someViewController` is deallocated.

#### Manually Removing Observers

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

#### Detailed Ownership Rules

* An observer’s observation of a resource is contingent upon one or more owners.
* Owners can be any kind of object.
* An observer may be its own owner.
* A resource keeps a strong reference to an observer as long as it has owners other than itself.
* An observer stops observing a resource as soon as all of its owners have been deallocated (or explicitly removed).

Observers affect the lifecycle of resources:

* A resource is eligible for deallocation if and only if it has no observers _and_ there are no other strong references to it from outside the Siesta framework.
* Eligible resources are only deallocated if there is memory pressure.
* At any time, there exists at _most_ one `Resource` instance per `Service` for a given URL.

These rules, while tricky when all spelled out, make the right thing the easy thing most of the time.

### Logging

Siesta features extensive logging. It is disabled by default, but you can turn it on with:

```swift
    Siesta.enabledLogCategories = LogCategory.common
```

…or for the full fire hose:

```swift
    Siesta.enabledLogCategories = LogCategory.all
```

Common practice is to add a DEBUG Swift compiler flag to your project (if you haven’t already done so):

<p align="center"><img alt="Build Settings → Swift Compiler Flags - Custom Flags → Other Swift Flags → Debug → -DDEBUG" src="Docs/images/debug-flag@2x.png" width=482 height=120></p>

…and then automatically enable logging for common categories in your API’s `init()` or your `applicationDidFinishLaunching`:

```swift
    #if DEBUG
        Siesta.enabledLogCategories = LogCategory.common
    #endif
```

## Examples

This repo includes a [simple example project](Examples/GithubBrowser).
