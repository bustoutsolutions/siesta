# Siesta

**iOS REST Client Framework**

Drastically simplifies app code by providing a client-side cache of observable models for RESTful resources.

* **OS:** iOS 8+
* **Languages:** Written in Swift, supports Swift and Objective-C
* **Build requirements:** Xcode 7 beta, Swift 2.0, Carthage
* **License:** MIT
* **Status:** Alpha, in active development. Works well, but API still in flux. Seeking feedback. Please experiment!

**Contents**

- [What’s It For?](#whats-it-for)
- [Features](#features)
- [Design Philosophy](#design-philosophy)
- [Installation](#installation)
- [Basic Usage](#basic-usage)
- Documentation
  - [User Guide](https://bustoutsolutions.github.io/siesta/guide/)
  - [API Docs](https://bustoutsolutions.github.io/siesta/api/)
  - [Specs](https://bustoutsolutions.github.io/siesta/specs/)
- [Examples](#examples)
- [Contributing & Getting Help](#contributing--getting-help)

## What’s It For?

### The Problem

Want your app to talk to an API? Welcome to your state nightmare!

You need to display response data whenever it arrives, unless the requesting ViewController is no longer visible, unless some other currently visible ViewController happens to want the same data. You should show a loading indicator (but watch out for race conditions that leave it stuck spinning forever), display user-friendly errors (but not redundantly — no modal alert dogpiles!), give users a retry mechanism … and hide all of that when a subsequent request succeeds. Be sure to avoid redundant requests. Oh, and remember not to retain your ViewController by accident in your callback closures. Unless you're supposed to.

What could possibly go wrong?

### The Solution

Siesta ends this headache by providing an observable model of a RESTful resource’s state. The model answers three basic questions:

* What is the latest data for this resource, if any?
* Did the latest request result in an error?
* Is there a request in progress?

…then provides notifications whenever the answers to these questions change.

Siesta handles all the transitions and corner cases to deliver these answers wrapped up with a pretty bow on top, letting you focus on your UI.

## Features

- Decouples UI component lifecycles from network request lifecycles
- Eliminates error-prone state tracking logic
- Eliminates redundant network requests
- Unified reporting for all errors: encoding, network, server-side, and parsing
- Transparent Etag / If-Modified-Since handling
- Painless handling for JSON and plain text, plus customizable response transformation
- Prebaked UI for loading & error handling
- Uses [Alamofire](https://github.com/Alamofire/Alamofire) for networking by default;
    inject a custom networking provider if you want to use a different networking library
- Debug-friendly, customizable logging
- Written in Swift with a great [Swift-centric API](https://bustoutsolutions.github.io/siesta/api/), but…
- …also works great from Objective-C thanks to a compatibility layer
- Lightweight (~2000 LOC). Won’t achieve sentience and attempt to destroy you.
- [Robust regression tests](https://bustoutsolutions.github.io/siesta/specs/)
- [Documentation](https://bustoutsolutions.github.io/siesta/guide/)

**Forthcoming:**

- Graceful handling for authenticated sessions
- Intelligent progress reporting that accounts for request, latency, and response
- Customizable data caching

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

---

## Installation

We recommend adding Siesta to your project using Carthage. You can also manually build the framework yourself.

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

Once you have the framework in your project, import Siesta and let the fun begin:

```swift
import Siesta
```

### CocoaPods

Coming soon, no later than when Xcode 7 goes out of beta.

---

## Basic Usage

Make a singleton for the REST API you want to use:

```swift
let MyAPI = Service(base: "https://api.example.com")
```

Now register your view controller — or view, or anything you like — to receive notifications whenever the resource’s state changes:

```swift
override func viewDidLoad() {
    super.viewDidLoad()

    MyAPI.resource("/profile").addObserver(self)
}
```

…and use those notifications to populate your UI.

```swift
@IBOutlet weak var nameLabel, colorLabel, errorLabel: UILabel!

func resourceChanged(resource: Resource, event: ResourceEvent) {
    nameLabel.text = resource.json["name"] as? String
    colorLabel.text = resource.json["favoriteColor"] as? String

    errorLabel.text = resource.latestError?.userMessage
}
```

Trigger a staleness-aware load when the view appears:

```swift
override func viewWillAppear(animated: Bool) {
    MyAPI.resource("/profile").loadIfNeeded()
}
```

…and you have a networked UI.

Add a loading indicator:

```swift
MyAPI.resource("/profile").addObserver(self) {
    [weak self] resource, event in

    if resource.loading {
        self?.activityIndicator.startAnimating()
    } else {
        self?.activityIndicator.stopAnimating()
    }
}
```

…or better yet, use Siesta’s prebaked `ResourceStatusOverlay` view to get an activity indicator, a nicely formatted error message, and a retry button for free:

```swift
class ProfileViewController: UIViewController, ResourceObserver {
    @IBOutlet weak var nameLabel, colorLabel: UILabel!
    
    let statusOverlay = ResourceStatusOverlay()

    override func viewDidLoad() {
        super.viewDidLoad()

        statusOverlay.embedIn(self)

        MyAPI.resource("/profile")
            .addObserver(self)
            .addObserver(statusOverlay)
    }

    override func viewDidLayoutSubviews() {
        statusOverlay.positionToCoverParent()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        MyAPI.resource("/profile").loadIfNeeded()
    }

    func resourceChanged(resource: Resource, event: ResourceEvent) {
        nameLabel.text = resource.json["name"] as? String
        colorLabel.text = resource.json["favoriteColor"] as? String
    }
}
```

Note that this example is not toy code. Together with its storyboard, **this small class is a fully armed and operational REST-backed user interface**.

---

## Documentation

- **[User Guide](https://bustoutsolutions.github.io/siesta/guide/)**
- **[API documentation](https://bustoutsolutions.github.io/siesta/api/)**
- **[Specs](https://bustoutsolutions.github.io/siesta/specs/)**

## Examples

This repo includes a [simple example project](https://github.com/bustoutsolutions/siesta/tree/master/Examples/GithubBrowser). Use Carthage to build its dependencies.

## Contributing & Getting Help

To report a bug, [file an issue](https://github.com/bustoutsolutions/siesta/issues/new).

To submit a feature request / cool idea, [file an issue](https://github.com/bustoutsolutions/siesta/issues/new).

To get help, please don’t file an issue! Post your question to [Stack Overflow](https://stackoverflow.com) and tag it with **siesta-swift**. (Be sure to include the tag. It triggers a notification.)
