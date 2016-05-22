//
//  Networking.swift
//  Siesta
//
//  Created by Paul on 2015/7/30.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

/**
  If you want to use a different networking library, implement this protocol and pass your implementation to
  `Service.init(...)`.

  See `NSURLSessionProvider` and `Extensions/Alamofire/Networking-Alamofire.swift` for implementation examples.
*/
public protocol NetworkingProvider: NetworkingProviderConvertible
    {
    /**
      Start the given request asynchronously, and return a `RequestNetworking` to control the request.

      If the request is cancelled, call the response closure with an error.

      - Note:

        This method will be called on the main thread. It is the implementation’s responsibility to ensure that
        network requests run asynchronously.

        Implementations may call the `completion` from a background thread.

      - Warning: Implementations **must** guarante that they will call the `completion` closure exactly once.
    */
    func startRequest(
            request: NSURLRequest,
            completion: RequestNetworkingCompletionCallback)
        -> RequestNetworking
    }

/**
  Network handling for a single request. Created by a `NetworkingProvider`. Implementations have three responsibilities:

  * start the request when `start(_:)` is called,
  * call the closure passed to `start(_:)` is called when the request is complete, and
  * optionally support cancelling requests in progress.
*/
public protocol RequestNetworking
    {
    /// Cancel this request, if possible.
    func cancel()

    /// Returns raw data used for progress calculation.
    var transferMetrics: RequestTransferMetrics { get }
    }

/// Used by `NetworkingProvider` implementations to report request progress.
public struct RequestTransferMetrics
    {
    /// Bytes of HTTP request body sent.
    public var requestBytesSent: Int64

    /// Total size of HTTP request body. Negative or nil indicates unknown size.
    /// Providers should ensure that `requestBytesSent == requestBytesTotal` when the request is complete, as this
    /// allows Siesta to include response latency in its progress calculation.
    public var requestBytesTotal: Int64?

    /// Bytes of HTTP response body received.
    public var responseBytesReceived: Int64

    /// Total expected size of HTTP response body. Negative or nil indicates unknown size.
    public var responseBytesTotal: Int64?
    }

/// Used by a `NetworkingProvider` implementation to pass the result of a network request back to Siesta.
public typealias RequestNetworkingCompletionCallback = (nsres: NSHTTPURLResponse?, body: NSData?, error: ErrorType?) -> Void

/**
  A convenience to turn create the appropriate `NetworkingProvider` for a variety of networking configuration objects.
  Used by the `Service` initializer.

  For example, instead of having to do this:

      Service(baseURL: "http://foo.bar", networking:
        NSURLSessionProvider(session:
            NSURLSession(configuration:
                NSURLSessionConfiguration.defaultSessionConfiguration()))

  …you can do this:

      Service(baseURL: "http://foo.bar", networking:
        NSURLSessionConfiguration.defaultSessionConfiguration()))

  Siesta supports conversion of the following types into a networking provider:

  - NSURLSession
  - NSURLSessionConfiguration
  - Alamofire.Manager

  …and you can add to the list by writing an extension to implement `NetworkingProviderConvertible`.
*/
public protocol NetworkingProviderConvertible
    {
    /// Returns a `NetworkingProvider` appropriate to the receipient.
    var siestaNetworkingProvider: NetworkingProvider { get }
    }

//:nodoc:
extension NetworkingProvider
    {
    /// You can pass a `NetworkingProvider` when creating a `Service` to override the default networking behavior.
    /// - SeeAlso: NetworkingProviderConvertible
    public var siestaNetworkingProvider: NetworkingProvider
        { return self }
    }
