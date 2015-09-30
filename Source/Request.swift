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
    ///
    /// I’m here all week! Thank you for reading the documentation!
    case DELETE
    }

/**
  Registers hooks to receive notifications about the status of a network request, and some request control.
  
  Note that these hooks are for only a _single request_, whereas `ResourceObserver`s receive notifications about
  _all_ resource load requests, no matter who initiated them. Note also that these hooks are available for _all_
  requests, whereas `ResourceObserver`s only receive notifications about changes triggered by `load()`, `loadIfNeeded()`,
  and `localDataOverride(_:)`.
  
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
      An estimate of the progress of the request, including request transfer, response transfer, and latency.
      Result is either in [0...1] or is NAN.
      
      The property will always be 1 if a request is completed. Note that the converse is not true: a value of 1 does
      not necessarily mean the request is completed; it means only that we estimate the request _should_ be completed
      by now. Use the `completed` property to test for actual completion.
    */
    var progress: Double { get }
    
    func progress(callback: Double -> Void) -> Self
    
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
        if case .Failure(let error) = self
            { return error.isCancellation }
        else
            { return false }
        }
    
    /// :nodoc:
    public var description: String
        {
        switch self
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
    // Basic metadata
    private let resource: Resource
    private let requestDescription: String
    
    // Networking
    private let nsreq: NSURLRequest
    internal var networking: RequestNetworking?  // present only after start()
    internal var cancelled: Bool = false
    
    // Progress
    var progress: Double = 0
    private var lastProgressBroadcast: Double?
    private var progressComputation: RequestProgress
    private var progressUpdateTimer: NSTimer?
    
    // Result
    private var responseInfo: ResponseInfo?
    internal var underlyingNetworkRequestCompleted = false      // so tests can wait for it to finish
    internal var completed: Bool { return responseInfo != nil }
    
    // Callbacks
    private var responseCallbacks: [ResponseCallback] = []
    private var progressCallbacks: [Double -> Void] = []

    init(resource: Resource, nsreq: NSURLRequest)
        {
        self.resource = resource
        self.nsreq = nsreq
        self.requestDescription = debugStr([nsreq.HTTPMethod, nsreq.URL])
        
        progressComputation = RequestProgress(isGet: nsreq.HTTPMethod == "GET")
        progressUpdateTimer =
            CFRunLoopTimerCreateWithHandler(
                    kCFAllocatorDefault,
                    CFAbsoluteTimeGetCurrent(),
                    resource.config.progressReportingInterval, 0, 0)
                { [weak self] _ in self?.updateProgress() }
        CFRunLoopAddTimer(CFRunLoopGetCurrent(), progressUpdateTimer, kCFRunLoopCommonModes)
        }
    
    deinit
        {
        progressUpdateTimer?.invalidate()
        }
    
    func start() -> Self
        {
        guard networking == nil else
            { fatalError("NetworkRequest.start() called twice") }
        
        guard !cancelled else
            {
            debugLog(.Network, [requestDescription, "will not start because it was already cancelled"])
            underlyingNetworkRequestCompleted = true
            return self
            }
        
        debugLog(.Network, [requestDescription])
        
        networking = resource.service.networkingProvider.startRequest(nsreq)
            {
            res, data, err in
            dispatch_async(dispatch_get_main_queue())
                { self.responseReceived(nsres: res, body: data, nserror: err) }
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
        
        networking?.cancel()
        
        // Prevent start() from have having any effect if it hasn't been called yet
        cancelled = true

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
    
    // MARK: Progress
    
    func progress(callback: Double -> Void) -> Self
        {
        progressCallbacks.append(callback)
        return self
        }
    
    private func updateProgress()
        {
        guard let networking = networking else
            { return }
        
        progressComputation.update(networking.transferMetrics)
        progress = progressComputation.fractionDone
        broadcastProgress()
        }
    
    private func broadcastProgress()
        {
        if lastProgressBroadcast != progress
            {
            lastProgressBroadcast = progress
            for callback in progressCallbacks
                { callback(progress) }
            }
        }
    
    // MARK: Response handling
    
    // Entry point for response handling. Triggered by RequestNetworking completion callback.
    private func responseReceived(nsres nsres: NSHTTPURLResponse?, body: NSData?, nserror: NSError?)
        {
        underlyingNetworkRequestCompleted = true
        
        debugLog(.Network, [nsres?.statusCode ?? nserror, "←", requestDescription])
        debugLog(.NetworkDetails, ["Raw response headers:", nsres?.allHeaderFields])
        debugLog(.NetworkDetails, ["Raw response body:", body?.length ?? 0, "bytes"])
        
        let responseInfo = interpretResponse(nsres, body, nserror)

        if shouldIgnoreResponse(responseInfo.response)
            { return }
        
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

    private func broadcastResponse(newInfo: ResponseInfo)
        {
        if shouldIgnoreResponse(newInfo.response)
            { return }
        
        progressUpdateTimer?.invalidate()
        progressComputation.complete()
        broadcastProgress()

        debugLog(.NetworkDetails, ["Response after transformer pipeline:", newInfo.isNew ? " (new data)" : " (data unchanged)", newInfo.response.dump("   ")])
        
        responseInfo = newInfo   // Remember outcome in case more handlers are added after request is already completed
        
        for callback in responseCallbacks
            { callback(newInfo) }
        responseCallbacks = []   // Fly, little handlers, be free!
        }
    
    private func shouldIgnoreResponse(newResponse: Response) -> Bool
        {
        guard let responseInfo = responseInfo else
            { return false }

        // We already received a response; don't broadcast another one.
        
        if !responseInfo.response.isCancellation
            {
            debugLog(.Network,
                [
                "WARNING: Received response for request that was already completed:", requestDescription,
                "This may indicate a bug in the NetworkingProvider you are using, or in Siesta.",
                "Please file a bug report: https://github.com/bustoutsolutions/siesta/issues/new",
                "\n    Previously received:", responseInfo.response,
                "\n    New response:", newResponse
                ])
            }
        else if !newResponse.isCancellation
            {
            // Sometimes the network layer sends a cancellation error. That’s not of interest if we already knew
            // we were cancelled. If we received any other response after cancellation, log that we ignored it.
            
            debugLog(.NetworkDetails,
                [
                "Received response, but request was already cancelled:", requestDescription,
                "\n    New response:", newResponse
                ])
            }
        
        return true
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
    
    func progress(callback: Double -> Void) -> Self
        {
        dispatch_async(dispatch_get_main_queue(), { callback(1) })
        return self
        }
    
    // Everything else is a noop
    
    func success(callback: Entity -> Void) -> Self { return self }
    func newData(callback: Entity -> Void) -> Self { return self }
    func notModified(callback: Void -> Void) -> Self { return self }
    
    func cancel() { }

    var completed: Bool { return true }
    var progress: Double { return 1 }
    }


private struct RequestProgress: Progress
    {
    private var uploadProgress, latencyProgress, downloadProgress: TaskProgress
    private var overallProgress: MonotonicProgress
    private var timeRequestSent: NSTimeInterval?
    
    init(isGet: Bool)
        {
        uploadProgress = TaskProgress(estimatedTotal: 8192)    // bytes
        latencyProgress = TaskProgress(estimatedTotal: 0.6)    // seconds
        downloadProgress = TaskProgress(estimatedTotal: 65536) // bytes
        overallProgress =
            MonotonicProgress(
                CompoundProgress(components:
                    (uploadProgress,   weight: isGet ? 0 : 1),
                    (latencyProgress,  weight: 0.5),
                    (downloadProgress, weight: isGet ? 1 : 0.1)))
        }
    
    mutating func update(metrics: RequestTransferMetrics)
        {
        updateByteCounts(metrics)
        updateLatency(metrics)
        }
    
    mutating func updateByteCounts(metrics: RequestTransferMetrics)
        {
        func optionalTotal(n: Int64?) -> Double?
            {
            if let n = n where n > 0
                { return Double(n) }
            else
                { return nil }
            }
        
        overallProgress.holdConstant
            {
            uploadProgress.actualTotal   = optionalTotal(metrics.requestBytesTotal)
            downloadProgress.actualTotal = optionalTotal(metrics.responseBytesTotal)
            }
        
        uploadProgress.completed   = Double(metrics.requestBytesSent)
        downloadProgress.completed = Double(metrics.responseBytesReceived)
        }

    mutating func updateLatency(metrics: RequestTransferMetrics)
        {
        if timeRequestSent == nil && metrics.requestBytesSent >= metrics.requestBytesTotal
            { timeRequestSent = NSDate.timeIntervalSinceReferenceDate() }
        
        if metrics.responseBytesReceived > 0
            {
            latencyProgress.completed = Double.infinity
            }
        else if let timeRequestSent = timeRequestSent
            {
            latencyProgress.completed = NSDate.timeIntervalSinceReferenceDate() - timeRequestSent
            }
        }
    
    mutating func complete()
        { overallProgress.child = TaskProgress.completed }
    
    var rawFractionDone: Double
        {
        return overallProgress.fractionDone
        }
    }

