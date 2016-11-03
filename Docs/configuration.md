# Configuration

Siesta decouples request _configuration_ from request _initiation_. Code can request a resource without knowing all the details of _how_ to request it. “I want to display the user’s profile. Request it if necessary; you know what to do. Tell me whenever it changes.”

Instead of appearing at the request creation site, your app-specific code for configuring requests is part of your `Service` setup. Configuration can apply across the entire service, to a specific resource or subset of resources, and even to a subset of request methods (e.g. different response parsing for a POST).

Configuration options include:

- HTTP headers,
- response parsing (covered in detail in the [next section](pipeline.md)),
- data expiration time, and
- arbitrary request decoration.

For the full set of configurable options, see the [`Configuration`](https://bustoutsolutions.github.io/siesta/api/Structs/Configuration.html) API docs.

## Applying Configuration

Configuration happens via [`Service.configure(…)`](https://bustoutsolutions.github.io/siesta/api/Classes/Service.html#//apple_ref/swift/Method/configure(_:requestMethods:description:configurer:)). It’s common practice to subclass `Service` and apply configuration in the initializer:

```swift
class MyAPI: Service {
  init() {
    super.init(baseURL: "https://api.example.com")

    // Global default headers
    configure {
      $0.headers["X-App-Secret"] = "2g3h4bkv234"
      $0.headers["User-Agent"] = "MyAwesomeApp 1.0"
    }
  }
}
```

To apply configuration to only a subset of resources, you can pass a pattern:

```swift
configure("/volcanos/*/status") {
  $0.expirationTime = 0.5  // default is 30 seconds
}
```

…or a predicate that matches `URL`:

```swift
configure(whenURLMatches: { $0.scheme == "https" }) {
  $0.headers["X-App-Secret"] = "2g3h4bkv234"
}
```

Configuration blocks run in the order they’re added. This lets you set global defaults, then override some of them for specific resources while leaving others untouched:

```swift
configure {
  $0.headers["User-Agent"] = "MyAwesomeApp 1.0"
  $0.headers["Accept"] = "application/json"
}

configure("/**/knob") {
  $0.headers["Accept"] = "doorknob/round, doorknob/handle, */*"
}
```

Note that the second block modifies the `Accept` header, but leaves `User-Agent` intact. Each configuration closure receives the same mutable `Configuration` in turn, and each can modify any part of it.

## Configuration That Changes

When the configuration closures have all run, the configuration freezes: resources hold an immutable copy of the configuration your closures produce.

How then can you handle configuration that changes over time — an authentication header, for example? You might be tempted to add more configuration every time something needs to change:

```swift
class MyAPI: Service {
  var authToken: String? {
    didSet {
      configure {  // 😱😱😱 WRONG 😱😱😱
        $0.headers["X-HappyApp-Auth-Token"] = self.authToken
      }
    }
  }
}
```

Don’t do this! You are creating an ever-growing list of configuration blocks, every one of which will run every time you touch a new resource.

Instead, the correct mechanism for altering configuration over time is:

- Add your configuration closures _once_ when setting up your service.
- Write them so that they grab any dynamic values from some authoritative source _outside_ the closure.
- When dynamic values change, force configuration blocks to rerun using [`invalidateConfiguration()`](https://bustoutsolutions.github.io/siesta/api/Classes/Service.html#//apple_ref/swift/Method/invalidateConfiguration()).

```swift
class MyAPI: Service {
  init() {
    super.init()
    
    // Call configure(…) only once during Service setup
    configure {
      $0.headers["X-HappyApp-Auth-Token"] = self.authToken  // NB: If service isn’t a singleton, use weak self
    }
  }

  …

  var authToken: String? {
    didSet {
      // Rerun existing configuration closure using new value
      invalidateConfiguration()

      // Wipe any cached state if auth token changes
      wipeResources()
    }
  }
}
```

## Why This Mechanism?

Because of the ephemeral nature of `Resource` instances, which can disappear when they’re not in use and there’s memory pressure, it wouldn’t work to configure them by giving `Resource` itself mutable configuration properties. Any such changes would vanish unpredictably.

Siesta thus asks you to provide your configuration via closures that can run on demand, whenever they’re needed. It is not up to your app to know exactly _when_ Siesta needs the configuration, only to know _how_ to derive it when it’s needed. Siesta is reasonably smart about caching configuration for a resource and only rebuilding it when necessary.

Configuration closures run:

- every time a `Resource` needs to compute (or recompute) its configuration
- in the order they were registered (so put your global config before resource-specific overrides)
- if and only if they apply to the resource in question.

## Decorating Requests via Configuration

Siesta’s configuration mechanism is quite robust, particularly when combining [`Configuration.decorateRequests(…)`](https://bustoutsolutions.github.io/siesta/api/Structs/Configuration.html#//apple_ref/swift/Method/decorateRequests(with:)) with request hooks and [`Request.chained(…)`](https://bustoutsolutions.github.io/siesta/api/Protocols/Request.html#//apple_ref/swift/Method/chained(whenCompleted:)).

For example, you could globally trigger a login prompt when you receive a response that indicates auth failure:

```swift
let authURL = authenticationResource.url

configure(
    whenURLMatches: { $0 != authURL },         // For all resources except auth:
    description: "catch auth failures") {

  $0.decorateRequests { _, req in
    req.onFailure { error in                   // If a request fails...
      if error.httpStatusCode == 401 {         // ...with a 401...
        showLoginScreen()                      // ...then prompt the user to log in
      }
    }
  }
}
```

Alternatively, suppose we persist the user’s password or other long-term auth, but the API uses auth tokens that expire periodically. The code below intercepts token expirations, automatically gets a fresh token, then repeats the newly authorized request — and makes that all appear to observers as if the initial request succeeded:

```swift
var authToken: String??

init() {
  ...
  configure("**", description: "auth token") {
    if let authToken = self.authToken {
      $0.headers["X-Auth-Token"] = authToken         // Set the token header from a var that we can update
    }
    $0.decorateRequests {
      self.refreshTokenOnAuthFailure(request: $1)
    }
  }
}

// Refactor away this pyramid of doom however you see fit
func refreshTokenOnAuthFailure(request: Request) -> Request {
  return request.chained {
    guard case .failure(let error) = $0.response,  // Did request fail…
      error.httpStatusCode == 401 else {           // …because of expired token?
        return .useThisResponse                    // If not, use the response we got.
    }

    return .passTo(
      self.createAuthToken().chained {             // If so, first request a new token, then:
        if case .failure = $0.response {           // If token request failed…
          return .useThisResponse                  // …report that error.
        } else {
          return .passTo(request.repeated())       // We have a new token! Repeat the original request.
        }
      }
    )
  }
}

func createAuthToken() -> Request {
  return tokenCreationResource
    .request(.post, json: userAuthData())
    .onSuccess {
      self.authToken = $0.jsonDict["token"] as? String  // Store the new token, then…
      self.invalidateConfiguration()                    // …make future requests use it
    }
  }
}
```

In these auth examples, note that the configuration uses `"**"`. This pattern only matches URLs under the `service.baseURL`, preventing auth tokens from accidentally being sent to other servers.
