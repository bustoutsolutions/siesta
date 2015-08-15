**[Siesta User Guide](https://github.com/bustoutsolutions/siesta/blob/master/Docs/index.md)**

# Observers

Code can observe changes to a resource, either by implementing the `ResourceObserver` protocol:

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

Observers receive a notification when a resource starts loading, receives new data, or receives an error. Each observer is also pinged immediately when it first starts observing, even if the resource has not changed. This lets you put all your UI-populating code in one place.

The simplest way to implement your observer is to ignore what king of event triggered the notification, and take an idempotent “update everything” approach:

```swift
func resourceChanged(resource: Resource, event: ResourceEvent) {
    // The convenience .dictContent accessor returns empty dict if no data,
    // so the same code can both populate and clear fields.
    let json = resource.dictContent
    nameLabel.text = json["name"] as? String
    favoriteColorLabel.text = json["favoriteColor"] as? String

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
