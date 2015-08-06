# Resource State

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

## Resource State is Multifaceted

Note that data, error, and loading are not mutually exclusive. For example, consider the following scenario:

* You load a resource, and the request succeeds.
* You refresh it later, and that second request fails.
* You initiate a third request.

At this point, `loading` is true, `latestError` holds information about the previously failed request, and `data` still gives the old cached data.

Siesta’s opinion is that your UI should decide for itself which of these things it prioritizes over the others. For example, you may prefer to refresh silently when there is already data available, or you may prefer to always show a spinner.

