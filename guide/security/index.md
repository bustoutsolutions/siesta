---
title: 'Security'
layout: default
---

# Security

## TLS Certificate and Public Key Pinning
There are at least three different ways to get [_TLS Certificate and Public Key Pinning_](https://www.owasp.org/index.php/Certificate_and_Public_Key_Pinning#What_Is_Pinning.3F) working in Siesta.

### 1. NSURLSessionDelegate

Declare your custom NSURLSessionDelegate to handle the _Authentication Challenge_, then configure an NSURLSession with your custom NSURLSessionDelegate just as you would without Siesta. Finally pass the NSURLSession as your networking provider when you create the Siesta service.

```swift
let certificatePinningSession = NSURLSession(
    configuration: NSURLSessionConfiguration.ephemeralSessionConfiguration(),
    delegate: MyCustomSessionPinningDelegate(),
    delegateQueue: nil)
let myService = Service(baseURL: "http://what.ever", networking: certificatePinningSession)
```

For an example code see the [OWASP guide](https://www.owasp.org/index.php/Certificate_and_Public_Key_Pinning#iOS
). It's for NSURLConnection but code is very similar.

### 2. Alamofire

If you are using Siesta with Alamofire as a [networking provider](http://bustoutsolutions.github.io/siesta/api/Protocols/NetworkingProvider.html), you could use the [Alamofire security utils](https://github.com/Alamofire/Alamofire#security).

### 3. TrustKit

[TrustKit](https://github.com/datatheorem/TrustKit) provides certificate pinning without modifying the App's source code.

<p class='guide-next'>Next: <strong><a href='../ui-components'>UI Components</a></p>
