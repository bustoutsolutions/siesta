# Security

## Authentication

### Using a Token Header

Many authentication schemes involve acquiring a token and passing it in a header. Do this via [`Service.configure(...)`](https://bustoutsolutions.github.io/siesta/api/Classes/Service.html#/s:FC6Siesta7Service9configureFS0_FT11descriptionSS10configurerFCVS_13Configuration7BuilderT__T_):

    class MyApi: Service {
        init() {
            ...

            configure { $0.config.headers["Authorization"] = authHeader }
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

When authentication succeeds:

    myAPI.authToken = authTokenFromOAuthLib

…and for logout:

    myAPI.authToken = nil

### Using OAuth

You will probably want a third-party lib such as [p2/OAuth2](https://github.com/p2/OAuth2) or [dongri/OAuthSwift](https://github.com/dongri/OAuthSwift) to handle the dance of acquiring an OAuth token. Once you have the token, integrate it exactly as you would any other token-based authentication. (See previous section.)

You could integrate OAuth more tightly with Siesta. For example, you could add special error handling hooks in your Siesta config to trigger a token refresh when you detect an OAuth expiration. _TODO: Examples of this_ However, third-party libraries usually provide satisfactory mechanisms for refreshing the token outside of Siesta.

## Handling Logout and Preventing Session Bleed

_TODO: Flesh this out. Quick sketch follows._

Two approaches, not mutually exclusive:

- Use `wipeResources()` to evict all authorization-dependent data on logout.
- Create new `Session` instance, and either wipe resources or discard all references to old session’s resources.

## Host Whitelisting

_TODO: Add section describing how to limit API calls to specific hosts, to limit accidental credential exposure when resolving relative URLs_

## TLS Certificate and Public Key Pinning

Siesta relies on the underlying networking provider, which by default is `NSURLSession`, to support [SSL public key pinning](https://www.owasp.org/index.php/Certificate_and_Public_Key_Pinning#What_Is_Pinning.3F). There are several ways to integrate this with Siesta.

### Using TrustKit

[TrustKit](https://github.com/datatheorem/TrustKit) provides certificate pinning by swizzling new behavior into `NSURLSession`, and thus requires no additional Siesta configuration.

### Using NSURLSessionDelegate

Create a custom `NSURLSessionDelegate` to handle the authentication challenge, then configure an `NSURLSession` with your custom `NSURLSessionDelegate` — all exactly as you would without Siesta. Then pass this `NSURLSession` as your networking provider when you create the Siesta service:

```swift
let certificatePinningSession = NSURLSession(
    configuration: NSURLSessionConfiguration.ephemeralSessionConfiguration(),
    delegate: MyCustomSessionPinningDelegate(),
    delegateQueue: nil)
let myService = Service(baseURL: "http://what.ever", networking: certificatePinningSession)
```

For example code, see the [OWASP guide](https://www.owasp.org/index.php/Certificate_and_Public_Key_Pinning#iOS
). That example is for the older `NSURLConnection` instead of `NSURLSession`, but the code is very similar.

### Using Alamofire

If you are using Siesta with Alamofire as a [networking provider](http://bustoutsolutions.github.io/siesta/api/Protocols/NetworkingProvider.html), you can use the [Alamofire security utilities](https://github.com/Alamofire/Alamofire#security).
