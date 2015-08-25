# Observers

Code can observe changes to a resource’s state, either by implementing the [`ResourceObserver`](https://bustoutsolutions.github.io/siesta/api/Protocols/ResourceObserver.html) protocol:

```swift
resource.addObserver(self)
```

…or by providing a callback closure:

```swift
resource.addObserver(owner: self) {
    resource, event in
    …
}
```

(Note that you’ll often need `[weak self]` in the closure to prevent a memory leak.)

Observers receive a notification whenever a resource’s state changes: when it starts loading, receives new data, or receives an error. Addditionally, each observer is also pinged immediately when it first starts observing, even if the resource has not changed. This lets you put all your UI-populating code in one place.

The simplest way to implement your observer is to ignore what king of event triggered the notification, and take an idempotent “update everything” approach:

```swift
func resourceChanged(resource: Resource, event: ResourceEvent) {
    // The convenience .json accessor returns empty dict if no data,
    // so the same code can both populate and clear fields.
    let json = resource.json
    nameLabel.text = json["name"] as? String
    favoriteColorLabel.text = json["favoriteColor"] as? String

    errorLabel.text = resource.latestError?.userMessage
}
```

Note the pleasantly reactive flavor this code takes on — without the overhead of adopting full-on Reactive programming with captial R.

## Resource Events

If updating the whole UI is an expensive operation (but it rarely is; benchmark first!), you can use the `event` parameter and the metadata in `latestData` and `latestError` to fine-tune your UI updates.

For example, if you have an expensive update you want to perform only when `latestData` changes:

```swift
func resourceChanged(resource: Resource, event: ResourceEvent) {
    if case .NewData = event {
        // Do expensive update
    }
}
```

If your API supports the `ETag` header, you could also use the `Entity.etag` property:

```swift
func resourceChanged(resource: Resource, event: ResourceEvent) {
    if displayedEtag != resource.latestData?.etag {
        displayedEtag = resource.latestData?.etag
        // Do expensive update
    }
}
```

See the API docs for [`Resource`](https://bustoutsolutions.github.io/siesta/api/Classes/Resource.html#/Observing%20Resources), [`ResourceEvent`](http://bustoutsolutions.github.io/siesta/api/Enums/ResourceEvent.html), and [`Entity`](http://bustoutsolutions.github.io/siesta/api/Structs/Entity.html) for more information.
