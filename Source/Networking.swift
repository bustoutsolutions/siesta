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
  
  See `AlamofireProvider` for an implementation example.
*/
public protocol NetworkingProvider
    {
    /**
      Create and return a `RequestNetworking` which is ready to perform the request described, but will not actually
      initiate it until its `start(_:)` method is called.
    */
    func networkingForRequest(request: NSURLRequest) -> RequestNetworking
    }

/**
  Network handling for a single request. Created by a `NetworkingProvider`. Implementations have three responsibilities:
  
  * start the request when `start(_:)` is called,
  * call the closure passed to `start(_:)` is called when the request is complete, and
  * optionally support cancelling requests in progress.
*/
public protocol RequestNetworking
    {
    /**
      Start the associated network request.
      
      Siesta will call this method at most once. Implementations **must** guarante that they will call the given
      response closure exactly once.
      
      If the request is cancelled, call the response closure with an `NSError`.
    */
    func start(response: (nsres: NSHTTPURLResponse?, body: NSData?, nserror: NSError?) -> Void)
    
    /// Cancel this request, if possible.
    func cancel()
    }

