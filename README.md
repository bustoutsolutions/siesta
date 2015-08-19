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
**Overview**

- [What’s It For?](#what%E2%80%99s-it-for)
  - [The Problem](#the-problem)
  - [The Solution](#the-solution)
- [Features](#features)
- [Design Philosophy](#design-philosophy)
- [Installation](#installation)
  - [Carthage](#carthage)
  - [CocoaPods](#cocoapods)
- [Basic Usage](#basic-usage)
- [Examples](#examples)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

**Further Documentation**

- [User Guide](Docs/index.md)
- [API Docs](https://bustoutsolutions.github.io/siesta/api/)
- [Specs](https://bustoutsolutions.github.io/siesta/specs/)

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

## Features

- [x] Decouples UI component lifecycles from network request lifecycles
- [x] Eliminates error-prone state tracking logic
- [x] Eliminates redundant network requests
- [x] Unified reporting for all errors: encoding, network, server-side, and parsing
- [x] Transparent Etag / If-Modified-Since handling
- [x] Painless handling for JSON and plain text, plus customizable response transformation
- [x] Prebaked UI for loading & error handling
- [x] Uses [Alamofire](https://github.com/Alamofire/Alamofire) for networking by default;
        inject a custom networking provider if you want to use a different networking library
- [x] Debug-friendly, customizable logging
- [x] Written in Swift with a great [Swift-centric API](https://bustoutsolutions.github.io/siesta/api/), but…
- [x] …also works great from Objective-C thanks to a compatibility layer
- [x] [Robust regression tests](https://bustoutsolutions.github.io/siesta/specs/)
- [x] [Documentation](Docs/index.md)

**Forthcoming:**

- [ ] Graceful handling for authenticated sessions
- [ ] Intelligent progress reporting that accounts for request, latency, and response
- [ ] Customizable data caching

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
func resourceChanged(resource: Resource, event: ResourceEvent) {
    let json = resource.dictContent
    nameLabel.text = json["name"] as? String
    favoriteColorLabel.text = json["favoriteColor"] as? String

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

…or better yet, use Siesta’s prebaked UI component to get an activity indicator, a nicely formatted error message, and a retry button for free:

```swift
class ProfileViewController: UIViewController, ResourceObserver {
    @IBOutlet weak var nameLabel, favoriteColorLabel: UILabel!
    
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
        let json = resource.dictContent
        nameLabel.text = json["name"] as? String
        favoriteColorLabel.text = json["favoriteColor"] as? String
    }
}
```

Note that this is not just a toy example. Together with its storyboard, **this small piece of code is a fully armed and operational REST-backed user interface**, complete with an activity indicator, content-type-aware threaded parsing, robust error handling, refresh throttling, and app-wide response data sharing.

See the [user guide](Docs/index.md) and [API documentation](https://bustoutsolutions.github.io/siesta/api/) for more info.

## Examples

This repo includes a [simple example project](Examples/GithubBrowser).
