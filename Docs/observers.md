# Observers

Code can observe changes to a resource’s state, either by implementing the [`ResourceObserver`](https://bustoutsolutions.github.io/siesta/api/Protocols/ResourceObserver.html) protocol:

```swift
resource.addObserver(self)
```

…or by providing a callback closure:

```swift
resource.addObserver(owner: self) {
    [weak self] resource, event in
    …
}
```

(Note that you’ll usually need `[weak self]` in the closure to prevent a memory leak.)

Observers receive a notification whenever a resource’s state changes: when it starts loading, receives new data, or receives an error. Additionally, each observer is also pinged immediately when it first starts observing, even if the resource has not changed. This lets you put all your update code in one place.

The simplest way to implement your observer is to ignore what kind of event triggered the notification, and take an idempotent “update everything” approach:

```swift
func resourceChanged(_ resource: Resource, event: ResourceEvent) {
    // The convenience .jsonDict accessor returns empty dict if no
    // data, so the same code can both populate and clear fields.
    let json = resource.jsonDict
    nameLabel.text = json["name"] as? String
    favoriteColorLabel.text = json["favoriteColor"] as? String

    errorLabel.text = resource.latestError?.userMessage
}
```

Note the pleasantly reactive flavor this code takes on — without the overhead of adopting full-on Reactive programming with a capital R.

(Aside: It would be the most natural thing in the world to wire a Siesta resource up to a reactive library. Pull requests welcome!)

## Resource Events

If updating the whole UI is an expensive operation (but it rarely is; benchmark first!), you can use the `event` parameter and the metadata in `latestData` and `latestError` to fine-tune your UI updates.

For example, if you have an expensive update you want to perform only when `latestData` changes:

```swift
func resourceChanged(_ resource: Resource, event: ResourceEvent) {
    if case .newData = event {
        // Do expensive update
    }
}
```

If your API supports the `ETag` header, you could also use the `Entity.etag` property:

```swift
func resourceChanged(_ resource: Resource, event: ResourceEvent) {
    if displayedEtag != resource.latestData?.etag {
        displayedEtag = resource.latestData?.etag
        // Do expensive update
    }
}
```

Use this technique judiciously. Lots of fine-grained logic like this is a bad code smell when using Siesta.

Here’s how the various `ResourceEvent` values map to `Resource` state changes:

|                    | `observers`    | `latestData` | `latestError` | `isLoading` | `timestamp` |
|:-------------------|:--------------:|:------------:|:-------------:|:-----------:|:-----------:|
| `observerAdded`    |  one added     |  –           |  –            |  –          |  –          |
| `requested`        |  –             |  –           |  –            | `true`      |  –          |
| `requestCancelled` |  –             |  –           |  –            | `false`*    |  –          |
| `newData`          |  –             |  updated     | `nil`         | `false`*    |  updated    |
| `notModified`      |  –             |  –           | `nil`         | `false`*    |  updated    |
| `error`            |  –             |  –           |  updated      | `false`*    |  updated    |

<small><strong>*</strong> If calls to `load(...)` forced multiple simultaneous load requests, `isLoading` may still be true even after an event that signals the completion of a request.</small>

See the API docs for [`Resource`](https://bustoutsolutions.github.io/siesta/api/Classes/Resource.html#/Observing%20Resources), [`ResourceEvent`](https://bustoutsolutions.github.io/siesta/api/Enums/ResourceEvent.html), and [`Entity`](https://bustoutsolutions.github.io/siesta/api/Structs/Entity.html) for more information.
