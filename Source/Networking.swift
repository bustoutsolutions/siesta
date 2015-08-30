//
//  Networking.swift
//  Siesta
//
//  Created by Paul on 2015/7/30.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

/**
  If you want to use a different networking library, implement this protocol and pass your implementation to
  `Service.init(base:networkingProvider:)`.
  
  See `NSURLSessionProvider` and `AlamofireProvider` for implementation examples.
*/
public protocol NetworkingProvider: NetworkingProviderConvertible
    {
    /**
      Start the given request asynchronously, and return a `RequestNetworking` to control the request.

      Implementations **must** guarante that they will call the given response closure exactly once.
      
      If the request is cancelled, call the response closure with an `NSError`.
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
    }

public typealias RequestNetworkingCompletionCallback = (nsres: NSHTTPURLResponse?, body: NSData?, nserror: NSError?) -> Void

public protocol NetworkingProviderConvertible
    {
    var siestaNetworkingProvider: NetworkingProvider { get }
    }

extension NetworkingProvider
    {
    public var siestaNetworkingProvider: NetworkingProvider
        { return self }
    }
