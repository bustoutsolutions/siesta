# Configuration

Siesta decouples request _configuration_ from request _initiation_. Code can request a resource without knowing all the details of _how_ to request it. “I want to display the user’s profile. Request it if necessary; you know what to do. Tell me whenever it changes.”

Instead of appearing at the request creation site, your app-specific code for configuring requests is part of your `Service` setup. Configuration can apply across the entire service, to a specific resource or subset of resources, and even to a subset of request methods (e.g. different response parsing for a POST).

Configuration options include:

- HTTP headers,
- response parsing (covered in detail in the [next section](pipeline.md)),
- data expiration time, and
- arbitrary request decoration.

For the full set of configurable options, see the [`Configuration`](http://bustoutsolutions.github.io/siesta/api/Structs/Configuration.html) API docs.

## Applying Configuration

Configuration happens via [`Service.configure(…)`](http://bustoutsolutions.github.io/siesta/api/Classes/Service.html#/s:FC6Siesta7Service9configureFTPS_31ConfigurationPatternConvertible_14requestMethodsGSqGSaOS_13RequestMethod__11descriptionGSqSS_10configurerFCVS_13Configuration7BuilderT__T_). It’s common practice to subclass `Service` and apply configuration in the initializer:

```swift
class MyAPI: Service {
  init() {
    super.init(baseURL: "https://api.example.com")

    // Global default headers
    configure {
      $0.config.headers["X-App-Secret"] = "2g3h4bkv234"
      $0.config.headers["User-Agent"] = "MyAwesomeApp 1.0"
    }
  }
}
```

To apply configuration to only a subset of resources, you can pass a pattern:

```swift
configure("/volcanos/*/status") {
  $0.config.expirationTime = 0.5  // default is 30 seconds
}
```

…or a predicate that matches `NSURL`:

```swift
configure(whenURLMatches: { $0.scheme == "https" }) {
  $0.config.headers["X-App-Secret"] = "2g3h4bkv234"
}
```

Configuration blocks run in the order they’re added. This lets you set global defaults, then override some of them for specific resources while leaving others untouched:

```swift
configure {
  $0.config.headers["User-Agent"] = "MyAwesomeApp 1.0"
  $0.config.headers["Accept"] = "application/json"
}

configure("/**/knob") {
  $0.config.headers["Accept"] = "doorknob/round, doorknob/handle, */*"
}
```

Note that the second block modifies the `Accept` header, but leaves `User-Agent` intact. Each configuration closure receives the same mutable `Configuration` in turn, and each can modify any part of it.

## Configuration That Changes

When the configuration closures have all run, the configuration freezes: resources hold an immutable copy of the configuration your closures produce.

How then can you handle configuration that changes over time — an authentication header, for example? You might be tempted to add more configuration every time something needs to change:

```swift
class MyAPI: Service {
  var authToken: String {
    didSet {
      configure​ {  // 😱😱😱 WRONG 😱😱😱
        $0.config.headers["X-HappyApp-Auth-Token"] = newValue
      }
    }
  }
}
```

Don’t do this! You are creating an ever-growing list of configuration blocks, every one of which will run every time you touch a new resource.

Instead, the correct mechanism for altering configuration over time is:

- Add your configuration closures _once_ when setting up your service.
- Write them so that they grab any dynamic values from some authoritative source _outside_ the closure.
- When dynamic values change, force configuration blocks to rerun using [`invalidateConfiguration()`](http://bustoutsolutions.github.io/siesta/api/Classes/Service.html#/s:FC6Siesta7Service23invalidateConfigurationFT_T_).

```swift
class MyAPI: Service {
  init() {
    // Call configure(…) only once during Service setup
    configure​ {
      $0.config.headers["X-HappyApp-Auth-Token"] = self.authToken  // NB: If service isn’t a singleton, use weak self
    }
  }

  …

  var authToken: String {
    didSet {
      // Rerun existing configuration closure using new value
      invalidateConfiguration()

      // Wipe any Siesta’s cached state if auth token changes
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

Siesta’s configuration mechanism is quite robust, particularly when combining [`Configuration.beforeStartingRequest(_:)`](https://bustoutsolutions.github.io/siesta/api/Structs/Configuration.html#/s:FV6Siesta13Configuration21beforeStartingRequestFRS0_FFTCS_8ResourcePS_7Request__T_T_) with request hooks. For example:

```swift
let authURL = authenticationResource.url

configure(
    { url in url != authURL },                 // For all resources except auth:
    description: "catch auth failures") {

  $0.config.beforeStartingRequest { _, req in
    req.onFailure { error in                   // If a request fails...
      if error.httpStatusCode == 401 {         // ...with a 401...
        showLoginScreen()                      // ...then prompt the user to log in
      }
    }
  }

}
```
