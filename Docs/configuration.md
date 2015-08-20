# Configuration

Siesta decouples request _configuration_ from request _initiation_. Any code can request a resource without knowing all the details of _how_ to request it, e.g.: “I want to display the user’s profile. Request it if necessary; you know what to do. Tell me whenever it changes.”

Siesta therefore needs to let you customize requests on a per-resource basis, not just a per-request basis. However, because of the ephemeral nature of `Resource` instances, you cannot configure them by setting properties on a resource. Any such changes would vanish unpredictably during periods of low memory. Notice that everything in [the `Resource` class’s API](http://bustoutsolutions.github.io/siesta/api/Classes/Resource.html) is either (1) read-only or (2) related to requesting and updating content, not configuration.

All of a resource’s customizable options are in the [Configuration](http://bustoutsolutions.github.io/siesta/api/Structs/Configuration.html) struct. This struct appears as a property of `Resource`, but it is read-only (and thus immutable — Swift’s most brilliant feature). To change configuration options, you provide closures to [`Service.configure(...)`](http://bustoutsolutions.github.io/siesta/api/Classes/Service.html#/Resource%20Configuration).

Your configuration closures receive a mutable copy of the configuration, which they can reference as `$0.config`.  Each closure can apply globally across the service, a single resource, or a subset of resources specified by shell-like pattern or custom predicate. Closures can modify the mutable configuration before the resource receives it and it becomes immutable.

Configuration closures are run:

- every time a `Resource` needs to compute (or recompute) its configuration
- in the order they were registered (so put your global config before resource-specific overrides)
- if and only if they apply to the resource in question.

## Example! Please!

Yes, that was all a little heady. Here you go:

```swift
class MyAPI: Service {
  init() {
    super.init(base: "https://api.example.com")

    // Global config
    configure {
      $0.config.headers["User-Agent"] = "MyAwesomeApp 1.0"
      $0.config.headers["X-App-Secret"] = "2g3h4bkv234"
      $0.config.headers["Accept"] = "application/json"
    }

    configure("/**/image") {
      // At this point, global config above has already run.
      // We change one header, but leave the others untouched.
      $0.config.headers["Accept"] = "image/png, image/jpeg, */*"
      $0.config.responseTransformers.add(MyCustomImageParser())
    }

    configure("/volcanos/*/status") {
      $0.config.expirationTime = 0.5  // default is 30 seconds
    }
  }
}
```

This configuration mechanism is quite robust, particularly when combining [`Configuration.beforeStartingRequest(_:)`](https://bustoutsolutions.github.io/siesta/api/Structs/Configuration.html#/s:FV6Siesta13Configuration21beforeStartingRequestFRS0_FFTCS_8ResourcePS_7Request__T_T_) with request hooks. For example:

```swift
let authURL = authenticationResource.url

configure({ url in url != authURL }, description: "catch auth failures") {
  $0.config.beforeStartingRequest { _, req in  // For all resources except auth:
    req.failure { error in                     // If a request fails...
      if error.httpStatusCode == 401 {         // ...with a 401...
        showLoginScreen()                      // ...then prompt the user to log in
      }
    }
  }
}
```

See the documentation for [`Service.invalidateConfiguration()`](http://bustoutsolutions.github.io/siesta/api/Classes/Service.html#/s:FC6Siesta7Service23invalidateConfigurationFS0_FT_T_) for information about dynamic configuration, e.g. authentication tokens.
