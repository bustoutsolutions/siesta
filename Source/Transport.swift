//
//  Transport.swift
//  Siesta
//
//  Created by Paul on 2015/7/30.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

/**
  If you want to use a different networking library, implement this protocol and pass your implementation to
  `Service.init(base:transportProvider:)`.
  
  See `AlamofireTransportProvider` for an implementation example.
*/
public protocol TransportProvider
    {
    /**
      Create and return a `RequestTransport` which is ready to perform the request described, but will not actually
      initiate it until its `start(_:)` method is called.
    */
    func transportForRequest(request: NSURLRequest) -> RequestTransport
    }

/**
  Network handling for a single request. Created by a `TransportProvider`. Implementations have three responsibilities:
  
  * start the request when `start(_:)` is called,
  * call the closure passed to `start(_:)` is called when the request is complete, and
  * optionally support cancelling requests in progress.
*/
public protocol RequestTransport
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
    
    /// Return true if cancel() has been called. Does not guarantee that the request did not make it to the server.
    var isCancelled: Bool { get }
    }

