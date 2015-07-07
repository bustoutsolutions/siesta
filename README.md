# Siesta

iOS REST Client Framework

## The Problem

Want your app to talk to an API? Welcome to your state nightmare!

You need to display response data whenever it arrives, unless the requesting ViewController is no longer visible, unless some other currently visible ViewController happens to want the same data. You should show a loading indicator, display user-friendly errors (but no modal alert dogpiles!), give users a retry mechanism, and hide all that when a subsequent request succeeds. Be sure to avoid redundant requests, of course. Oh, and remember not to retain your ViewController by accident in your callback closures. What could possibly go wrong?

## The Solution

Siesta ends this headache by providing an observable model of a RESTful resource’s state. The Siesta `Resource` model answers three basic questions:

* What is the latest available data for this resource, if any?
* Did the last request result in an error?
* Is there a request currently in progress?

Siesta handles all the transitions and corner cases, letting you focus on your UI.

## Features

* Decouples UI state from network request state
* Observer model eliminates complex, error-prone state tracking logic
* Coordinates request tracking and data sharing across ViewControllers
* Eliminates redundant network requests
* Provides transparent Etag / If-Modified-Since handling

Coming soon…er or later:

* Configurable API-wide data parsing
* Intelligent progress reporting that accounts for request, latency, and response
* Customizable data caching
* Prepacked UI components for error overlay and progress bar

## Usage

Create a `Service` instance for each API your app uses. You can use any mechanism you like for sharing a service instance across your UI. The typical approach is to make it a singleton:

```swift
import Siesta

class MyAPI: Service {
    static let instance = MyAPI(base: "https://api.example.com")
}
```

You can ask a `Service` for a `Resource` instances:

```swift
MyAPI.instance.resource("/profile")
MyAPI.instance.resource("/items").child("123").child("related")
MyAPI.instance.resource("/items/123/related") // returns same object as above
```

To trigger a network request:

```swift
someResource.loadIfNeeded()
```

Don’t worry about calling `loadIfNeeded()` too often. Call it in your `viewWillAppear()`. Call it 50 times a second. No problem! It automatically suppresses redundant requests. (Data expiration time is configurable on a per-service and per-resource level.)

UI components register to receive notifications when a resource changes, either by implementing the `ResourceObserver` protocol or by providing an observer closure. 

```swift
MyAPI.instance.resource("/profile").addObserver(self)
```

An observer is called every time a resource starts loading, receives new data, or receives an error. Each observer is also called immediately when it starts observing, even if the resource has not changed.

The simplest way to implement your observer to update your entire UI, regardless of the triggering event:

```swift
func resourceChanged(resource: Resource, event: ResourceEvent) {
    activityIndicator.hidden = !resource.loading

    // use empty JSON if there is no data, so that fields get cleared
    let json = (resource.data as? JSON) ?? JSON([:])
    nameLabel.text = json["name"].string
    favoriteColorLabel.text = json["favoriteColor"].string

    errorOverlay.visible = (resource.latestError != nil)
    errorLabel.text = resource.latestError?.userMessage
}
```

Note the pleasantly reactive flavor the code takes on with this approach.

If updating the whole UI is an expensive operation, you can use the `event` parameter and the metadata in `latestData` and `latestError` to fine-tune your UI updates.

Note that a resource might have failed on the last request, have older valid data, _and_ have a new request in progress. Siesta does not dictate which of these take precedence in your UI. It just tells you the current state of affairs, and leaves it to you to determine how to display it. Want to always show the latest data, even if there was a more recent error? No problem. Only show a loading indicator if no data is present? You can do that.

Putting it all together:

```swift
class ProfileViewController: UIViewController, ResourceObserver {

    override func viewDidLoad() {
        super.viewDidLoad()

        MyAPI.instance.resource("/profile").addObserver(self)
    }

    override func viewWillAppear(animated: Bool) {
        MyAPI.instance.resource("/profile").loadIfNeeded()
    }

    func resourceChanged(resource: Siesta.Resource, event: Siesta.ResourceEvent) {
        activityIndicator.hidden = !resource.loading

        let json = (resource.data as? JSON) ?? JSON([:])
        nameLabel.text = json["name"].string
        favoriteColorLabel.text = json["favoriteColor"].string

        errorOverlay.visible = (resource.latestError != nil)
        errorLabel.text = resource.latestError?.userMessage
    }
}
```
