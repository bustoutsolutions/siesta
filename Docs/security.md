# Security

## Authentication

### Using a Token Header

Many authentication schemes involve acquiring a token and passing it in a header. Do this via [`Service.configure(...)`](https://bustoutsolutions.github.io/siesta/api/Classes/Service.html#//apple_ref/swift/Method/configure(_:requestMethods:description:configurer:)):

```swift
class MyAPI: Service {
    init() {
        ...

        configure { $0.headers["Authorization"] = self.authHeader }
    }

    var authHeader: String? {
        didSet {
            // Clear any cached data now that auth has changed
            wipeResources()

            // Force resources to recompute headers next time they’re fetched
            invalidateConfiguration()
        }
    }
}
```

When authentication succeeds:

```swift
myAPI.authHeader = authHeaderFromSuccessfulAuthRequest
```

…and for logout:

```swift
myAPI.authHeader = nil
```

### Using OAuth

You will probably want a third-party lib such as [p2/OAuth2](https://github.com/p2/OAuth2) or [dongri/OAuthSwift](https://github.com/dongri/OAuthSwift) to handle the dance of acquiring an OAuth token. Once you have the token, integrate it exactly as you would any other token-based authentication. (See previous section.)

You could integrate OAuth more tightly with Siesta. For example, you could add special error handling hooks in your Siesta config to trigger a token refresh when you detect an OAuth expiration. _TODO: Examples of this_ However, third-party libraries usually provide satisfactory mechanisms for refreshing the token outside of Siesta.

## Handling Logout and Preventing Session Bleed

_TODO: Flesh this out. Quick sketch follows._

Two approaches, not mutually exclusive:

- Use [`wipeResources()`](https://bustoutsolutions.github.io/siesta/api/Classes/Service.html#//apple_ref/swift/Method/wipeResources(matching:)) to evict all authorization-dependent data on logout.
- Create a new `Service` instance, and either wipe resources or discard all references to the old service and all of its resources.

## Host Whitelisting

A Siesta service will accept URLs that point at _any_ server. [`Service.baseURL`](https://bustoutsolutions.github.io/siesta/api/Classes/Service.html#//apple_ref/swift/Property/baseURL) is a convenience, not a constraint. Calls like [`Service.resource(absoluteURL:)`](https://bustoutsolutions.github.io/siesta/api/Classes/Service.html#//apple_ref/swift/Method/resource(absoluteURL:)) and [`Resource.relative(_:)`](https://bustoutsolutions.github.io/siesta/api/Classes/Resource.html#//apple_ref/swift/Method/relative(_:)) will let you point a resource at _any_ server on the internet.

This means it is up to you to ensure that you do not accidentally send sensitive information to untrusted servers. This is of particular concern if your service configuration sets authentication headers. It is a wise precaution to insert sanity checks to make sure it only sends them to specific hosts.

The simplest such check is to use the configuration pattern `"**"`, which matches all URLs under `baseURL`, and _only_ those URLs:

```swift
service.configure("**", description: "auth token") {
  $0.headers["X-Auth-Token"] = authToken
}
```

A more drastic measure is to forcibly cut off all requests that attempt to reach a non-whitelisted server:

```swift
service.configure(whenURLMatches: { $0.host != "api.example.com" }) {
  $0.decorateRequests {
    _ in Resource.failedRequest(
      RequestError(
        userMessage: "Attempted to connect to unauthorized server",
        cause: UnauthorizedServer()))
  }
}
```

## TLS Certificate and Public Key Pinning

Siesta relies on the underlying networking provider, which by default is `URLSession`, to support [SSL public key pinning](https://www.owasp.org/index.php/Certificate_and_Public_Key_Pinning#What_Is_Pinning.3F). There are several ways to integrate this with Siesta.

### Using TrustKit

[TrustKit](https://github.com/datatheorem/TrustKit) provides certificate pinning by swizzling new behavior into `URLSession`, and thus requires no additional Siesta configuration.

### Using URLSessionDelegate

Create a custom `URLSessionDelegate` to handle the authentication challenge, then configure an `URLSession` with your custom `URLSessionDelegate` — all exactly as you would without Siesta. Then pass this `URLSession` as your networking provider when you create the Siesta service:

```swift
let certificatePinningSession = URLSession(
    configuration: URLSessionConfiguration.ephemeral,
    delegate: MyCustomSessionPinningDelegate(),
    delegateQueue: nil)
let myService = Service(baseURL: "http://what.ever", networking: certificatePinningSession)
```

For example code, see the [OWASP guide](https://www.owasp.org/index.php/Certificate_and_Public_Key_Pinning#iOS
). That example is for the older `URLConnection` instead of `URLSession`, but the code is very similar.

### Using Alamofire

If you are using Siesta with Alamofire as a [networking provider](https://bustoutsolutions.github.io/siesta/api/Protocols/NetworkingProvider.html), you can use the [Alamofire security utilities](https://github.com/Alamofire/Alamofire#security).
