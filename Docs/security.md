# Security

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
