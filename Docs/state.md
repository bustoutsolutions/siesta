# Resource State

The [`Resource`](https://bustoutsolutions.github.io/siesta/api/Classes/Resource.html) class answers three basic questions:

**Q.** What is the latest data for the resource we have locally, if any?<br>
**A.** [`latestData`](https://bustoutsolutions.github.io/siesta/api/Classes/Resource.html#//apple_ref/swift/Property/latestData) and its [convenience accessors](https://bustoutsolutions.github.io/siesta/api/Protocols/TypedContentAccessors.html)

**Q.** Did the last attempt to load it result in an error?<br>
**A.** [`latestError`](https://bustoutsolutions.github.io/siesta/api/Classes/Resource.html#//apple_ref/swift/Property/latestError)

**Q.** Is there a request in progress?<br>
**A.** [`isLoading`](https://bustoutsolutions.github.io/siesta/api/Classes/Resource.html#//apple_ref/swift/Property/isLoading) and [`isRequesting`](https://bustoutsolutions.github.io/siesta/api/Classes/Resource.html#//apple_ref/swift/Property/isRequesting)

## The State Properties

```swift
resource.latestData?.content // Gives the content of the last successful load. This
                             // is the fully parsed content, after it has run through
                             // the transformer pipeline.

resource.latestData?.headers // Because metadata matters too

resource.text                // Convenience accessors return empty string/dict/array
resource.jsonDict            // if data is either (1) not present or (2) not of the
resource.jsonArray           // expected type. This reduces futzing with optionals.

resource.typedContent()      // Convenience for casting content to arbitrary types.
                             // Especially useful if you configured the transformer
                             // pipeline to return models.
```

A resource knows whether it currently is loading, which lets you show/hide a spinner or progress bar:

```swift
resource.isRequesting        // True if any requests for this resource are in progress
resource.isLoading           // True if any requests in progress will update
                             // latestData / latestError upon completion.
```

…and it knows whether the last request resulted in an error:

```swift
resource.latestError               // Present if latest load attempt failed
resource.latestError?.userMessage  // String suitable for display in UI
```

That `latestError` struct rolls up many different kinds of error — encoding errors, transport-level errors, HTTP errors, and client-side parse errors — into a single consistent structure that’s easy to wrap in a UI.

## Resource State is Multifaceted

Note that data, error, and the loading flag are not mutually exclusive. For example, consider the following scenario:

* You load a resource, and the request succeeds.
* You refresh it later, and that second request fails.
* You initiate a third request.

At this point, `isLoading` is true, `latestError` holds information about the previously failed request, and `latestData` still gives the old cached data.

Siesta’s opinion is that your UI should decide for itself which of these things it prioritizes over the others. For example, you may prefer to refresh silently when there is already data displayed, or you may prefer to show a spinner on refresh. You may prefer to show a modal error message, an unobtrusive error popup, or existing data with no error message at all. It’s up to you.
