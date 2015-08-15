//
//  Request.swift
//  Siesta
//
//  Created by Paul on 2015/7/20.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

/**
  HTTP request methods.
  
  See the various `Resource.request(...)` methods.
*/
public enum RequestMethod: String
    {
    /// GET
    case GET
    
    /// POST. Just POST. Doc comment is the same as the enum.
    case POST
    
    /// So you’re really reading the docs for all these, huh?
    case PUT
    
    /// OK then, I’ll reward your diligence. Or punish it, depending on your level of refinement.
    ///
    /// What’s the difference between a poorly maintained Greyhound terminal and a lobster with breast implants?
    case PATCH
    
    /// One’s a crusty bus station, and the other’s a busty crustacean.
    /// Thank you for reading the documentation!
    case DELETE
    }

/**
  Registers hooks to receive notifications about the status of a network request, and some request control.
  
  Note that these hooks are for only a _single request_, whereas `ResourceObserver`s receive notifications about
  _all_ resource load requests, no matter who initiated them. Note also that these hooks are available for _all_
  requests, whereas `ResourceObserver`s only receive notifications about changes triggered by `load()`, `loadIfNeeded()`,
  and `localEntityOverride(_:)`.
  
  There is no race condition between a callback being added and a response arriving. If you add a callback after the
  response has already arrived, the callback is still called as usual.
  
  Request guarantees that it will call a given callback _at most_ one time.
  
  Callbacks are always called on the main queue.
*/
public protocol Request: AnyObject
    {
    /// Call the closure once when the request finishes for any reason.
    func completion(callback: Response -> Void) -> Self
    
    /// Call the closure once if the request succeeds.
    func success(callback: Entity -> Void) -> Self
    
    /// Call the closure once if the request succeeds and the data changed.
    func newData(callback: Entity -> Void) -> Self
    
    /// Call the closure once if the request succeeds with a 304.
    func notModified(callback: Void -> Void) -> Self

    /// Call the closure once if the request fails for any reason.
    func failure(callback: Error -> Void) -> Self
    
    /**
      True if the request has received and handled a server response, encountered a pre-request client-side side error,
      or been cancelled.
    */
    var completed: Bool { get }
    
    /**
      Cancel the request if it is still in progress. Has no effect if a response has already been received.
        
      If this method is called while the request is in progress, it immediately triggers the `failure`/`completion`
      callbacks with an `NSError` with the domain `NSURLErrorDomain` and the code `NSURLErrorCancelled`.
      
      Note that `cancel()` is not guaranteed to stop the request from reaching the server. In fact, it is not guaranteed
      to have any effect at all on the underlying request, subject to the whims of the `NetworkingProvider`. Therefore,
      after calling this method on a mutating request (POST, PUT, etc.), you should consider the service-side state of
      the resource to be unknown. Is it safest to immediately call either `Resource.load()` or `Resource.wipe()`.
      
      This method _does_ guarantee, however, that after it is called, even if a network response does arrive it will be
      ignored and not trigger any callbacks.
    */
    func cancel()
    }

/**
  The outcome of a network request: either success (with an entity representing the resource’s current state), or
  failure (with an error).
*/
public enum Response: CustomStringConvertible
    {
    /// The request succeeded, and returned the given entity.
    case Success(Entity)
    
    /// The request failed because of the given error.
    case Failure(Error)
    
    /// True if this is a cancellation response
    public var isCancellation: Bool
        {
        if case .Failure(let error) = self,
            let nserror = error.nsError
            where nserror.domain == NSURLErrorDomain
               && nserror.code == NSURLErrorCancelled
            { return true }
        else
            { return false }
        }
    
    /// :nodoc:
    public var description: String
        {
        switch(self)
            {
            case .Success(let value): return debugStr(value)
            case .Failure(let value): return debugStr(value)
            }
        }
    }

private typealias ResponseInfo = (response: Response, isNew: Bool)
private typealias ResponseCallback = ResponseInfo -> Void

internal final class NetworkRequest: Request, CustomDebugStringConvertible
    {
    private let resource: Resource
    private let requestDescription: String
    private var networking: RequestNetworking
    private var responseCallbacks: [ResponseCallback] = []
    
    private var responseInfo: ResponseInfo?
    var completed: Bool { return responseInfo != nil }

    init(resource: Resource, nsreq: NSURLRequest)
        {
        self.resource = resource
        self.requestDescription = debugStr([nsreq.HTTPMethod, nsreq.URL])
        self.networking = resource.service.networkingProvider.networkingForRequest(nsreq)
        }
    
    func start() -> Self
        {
        if !completed
            {
            debugLog(.Network, [requestDescription])
            networking.start(responseReceived)
            }
        
        return self
        }
    
    func cancel()
        {
        guard !completed else
            {
            debugLog(.Network, ["cancel() called but request already completed:", requestDescription])
            return
            }
        
        debugLog(.Network, ["Cancelled", requestDescription])
        
        networking.cancel()

        broadcastResponse((
            response: .Failure(Error(
                userMessage: "Request cancelled",
                error: NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled, userInfo: nil))),
            isNew: true))
        }
    
    // MARK: Callbacks

    func completion(callback: Response -> Void) -> Self
        {
        addResponseCallback
            {
            response, _ in
            callback(response)
            }
        return self
        }
    
    func success(callback: Entity -> Void) -> Self
        {
        addResponseCallback
            {
            response, _ in
            if case .Success(let entity) = response
                { callback(entity) }
            }
        return self
        }
    
    func newData(callback: Entity -> Void) -> Self
        {
        addResponseCallback
            {
            response, isNew in
            if case .Success(let entity) = response where isNew
                { callback(entity) }
            }
        return self
        }
    
    func notModified(callback: Void -> Void) -> Self
        {
        addResponseCallback
            {
            response, isNew in
            if case .Success = response where !isNew
                { callback() }
            }
        return self
        }
    
    func failure(callback: Error -> Void) -> Self
        {
        addResponseCallback
            {
            response, _ in
            if case .Failure(let error) = response
                { callback(error) }
            }
        return self
        }
    
    private func addResponseCallback(callback: ResponseCallback)
        {
        if let responseInfo = responseInfo
            {
            // Request already completed. Callback can run immediately, but queue it on the main thread so that the
            // caller can finish their business first.
            
            dispatch_async(dispatch_get_main_queue())
                { callback(responseInfo) }
            }
        else
            {
            // Request not yet completed.
            
            responseCallbacks.append(callback)
            }
        }
    
    private func broadcastResponse(newInfo: ResponseInfo)
        {
        if let responseInfo = responseInfo
            {
            // We already received a response; don't broadcast another one.
            
            if !responseInfo.response.isCancellation
                {
                debugLog(.Network,
                    [
                    "WARNING: Received response for request that was already completed:", requestDescription,
                    "This may indicate a bug in the NetworkingProvider you are using, or in Siesta.",
                    "Please file a bug report: https://github.com/bustoutsolutions/siesta/issues/new",
                    "\n    Previously received:", responseInfo.response,
                    "\n    New response:", newInfo.response
                    ])
                }
            else if !newInfo.response.isCancellation
                {
                // Sometimes the network layer sends a cancellation error. That’s not of interest if we already knew
                // we were cancelled. If we received any other response after cancellation, log that we ignored it.
                
                debugLog(.NetworkDetails,
                    [
                    "Received response, but request was already cancelled:", requestDescription,
                    "\n    New info:", newInfo.response
                    ])
                }
            
            return
            }
        
        for callback in responseCallbacks
            { callback(newInfo) }
        
        responseCallbacks = []   // Fly, little handlers, be free!
        responseInfo = newInfo   // Remember outcome in case more handlers are added after request is already completed
        }
    
    // MARK: Response handling
    
    // Entry point for response handling. Passed as a callback closure to RequestNetworking.
    private func responseReceived(nsres: NSHTTPURLResponse?, body: NSData?, nserror: NSError?)
        {
        debugLog(.Network, [nsres?.statusCode ?? nserror, "←", requestDescription])
        
        let responseInfo = interpretResponse(nsres, body, nserror)
        debugLog(.NetworkDetails, ["Raw response:", responseInfo.response, responseInfo.isNew ? "(new)" : "(unchanged)"])
        
        transformResponse(responseInfo, then: broadcastResponse)
        }
    
    private func interpretResponse(nsres: NSHTTPURLResponse?, _ body: NSData?, _ nserror: NSError?)
        -> ResponseInfo
        {
        if nsres?.statusCode >= 400 || nserror != nil
            {
            return (.Failure(Error(nsres, body, nserror)), true)
            }
        else if nsres?.statusCode == 304
            {
            if let entity = resource.latestData
                {
                return (.Success(entity), false)
                }
            else
                {
                return(
                    .Failure(Error(
                        userMessage: "No data",
                        debugMessage: "Received HTTP 304, but resource has no existing data")),
                    true)
                }
            }
        else if let body = body
            {
            return (.Success(Entity(nsres, body)), true)
            }
        else
            {
            return (.Failure(Error(userMessage: "Empty response")), true)
            }
        }
    
    private func transformResponse(rawInfo: ResponseInfo, then afterTransformation: ResponseInfo -> Void)
        {
        let transformer = resource.config.responseTransformers
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0))
            {
            let processedInfo =
                rawInfo.isNew
                    ? (transformer.process(rawInfo.response), true)
                    : rawInfo
            
            dispatch_async(dispatch_get_main_queue())
                { afterTransformation(processedInfo) }
            }
        }
    
    // MARK: Debug

    var debugDescription: String
        {
        return "Siesta.Request:"
            + String(ObjectIdentifier(self).uintValue, radix: 16)
            + "("
            + requestDescription
            + ")"
        }
    }


/// For requests that failed before they even made it to the network layer
internal final class FailedRequest: Request
    {
    private let error: Error
    
    init(_ error: Error)
        { self.error = error }
    
    func completion(callback: Response -> Void) -> Self
        {
        dispatch_async(dispatch_get_main_queue(), { callback(.Failure(self.error)) })
        return self
        }
    
    func failure(callback: Error -> Void) -> Self
        {
        dispatch_async(dispatch_get_main_queue(), { callback(self.error) })
        return self
        }
    
    // Everything else is a noop
    
    func success(callback: Entity -> Void) -> Self { return self }
    func newData(callback: Entity -> Void) -> Self { return self }
    func notModified(callback: Void -> Void) -> Self { return self }
    
    func cancel() { }

    var completed: Bool { return true }
    }
