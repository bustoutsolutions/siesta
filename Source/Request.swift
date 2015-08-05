//
//  Request.swift
//  Siesta
//
//  Created by Paul on 2015/7/20.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

public enum RequestMethod: String
    {
    case GET
    case POST
    case PUT
    case PATCH
    case DELETE
    }

/**
  Registers hooks to receive notifications about the status of a network request, and some request control.
  
  Note that these hooks are for only a _single request_, whereas `ResourceObserver`s receive notifications about
  _all_ resource load requests, no matter who initiated them. Note also that these hooks are available for _all_
  requests, whereas `ResourceObserver`s only receive notifications about changes triggered by `load()`, `loadIfNeeded()`,
  and `localDataOverride(_:)`.
*/
public protocol Request: AnyObject
    {
    func completion(callback: Response -> Void) -> Self    // success or failure
    func success(callback: ResourceData -> Void) -> Self   // success, may be same data
    func newData(callback: ResourceData -> Void) -> Self   // success, data modified
    func notModified(callback: Void -> Void) -> Self       // success, data not modified
    func failure(callback: ResourceError -> Void) -> Self  // error of any kind
    
    func cancel()
    }

public enum Response: CustomStringConvertible
    {
    case Success(ResourceData)
    case Failure(ResourceError)
    
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
    private var transport: RequestTransport
    private var responseCallbacks: [ResponseCallback] = []

    init(resource: Resource, nsreq: NSURLRequest)
        {
        self.resource = resource
        self.requestDescription = debugStr([nsreq.HTTPMethod, nsreq.URL])
        self.transport = resource.service.transportProvider.transportForRequest(nsreq)
        }
    
    func start() -> Self
        {
        debugLog(.Network, [requestDescription])
        
        transport.start(handleResponse)
        return self
        }
    
    func cancel()
        {
        debugLog(.Network, ["Cancelled:", requestDescription])
        
        transport.cancel()
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
    
    func success(callback: ResourceData -> Void) -> Self
        {
        addResponseCallback
            {
            response, _ in
            if case .Success(let data) = response
                { callback(data) }
            }
        return self
        }
    
    func newData(callback: ResourceData -> Void) -> Self
        {
        addResponseCallback
            {
            response, isNew in
            if case .Success(let data) = response where isNew
                { callback(data) }
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
    
    func failure(callback: ResourceError -> Void) -> Self
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
        responseCallbacks.append(callback)
        }
    
    private func triggerCallbacks(responseInfo: ResponseInfo)
        {
        for callback in self.responseCallbacks
            { callback(responseInfo) }
        }
    
    // MARK: Response handling
    
    // Entry point for response handling. Passed as a callback closure to RequestTransport.
    private func handleResponse(nsres: NSHTTPURLResponse?, body: NSData?, nserror: NSError?)
        {
        debugLog(.Network, [nsres?.statusCode, "←", requestDescription])
        
        let responseInfo = interpretResponse(nsres, body, nserror)
        
        debugLog(.NetworkDetails, ["Raw response:", responseInfo.response])
        
        processPayload(responseInfo)
        }
    
    private func interpretResponse(nsres: NSHTTPURLResponse?, _ body: NSData?, _ nserror: NSError?)
        -> ResponseInfo
        {
        if nsres?.statusCode >= 400 || nserror != nil
            {
            return (.Failure(ResourceError(nsres, body, nserror)), true)
            }
        else if nsres?.statusCode == 304
            {
            if let data = resource.latestData
                {
                return (.Success(data), false)
                }
            else
                {
                return(
                    .Failure(ResourceError(
                        userMessage: "No data",
                        debugMessage: "Received HTTP 304, but resource has no existing data")),
                    true)
                }
            }
        else if let body = body
            {
            return (.Success(ResourceData(nsres, body)), true)
            }
        else
            {
            return (.Failure(ResourceError(userMessage: "Empty response")), true)
            }
        }
    
    private func processPayload(rawInfo: ResponseInfo)
        {
        let transformer = resource.service.responseTransformers
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0))
            {
            let processedInfo =
                rawInfo.isNew
                    ? (transformer.process(rawInfo.response), true)
                    : rawInfo
            
            dispatch_async(dispatch_get_main_queue())
                { self.triggerCallbacks(processedInfo) }
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


/// For requests that failed before they even made it to the transport layer
internal class FailedRequest: Request
    {
    private let error: ResourceError
    
    init(_ error: ResourceError)
        { self.error = error }
    
    func completion(callback: Response -> Void) -> Self
        {
        dispatch_async(dispatch_get_main_queue(), { callback(.Failure(self.error)) })
        return self
        }
    
    func failure(callback: ResourceError -> Void) -> Self
        {
        dispatch_async(dispatch_get_main_queue(), { callback(self.error) })
        return self
        }
    
    // Everything else is a noop
    
    func success(callback: ResourceData -> Void) -> Self { return self }
    func newData(callback: ResourceData -> Void) -> Self { return self }
    func notModified(callback: Void -> Void) -> Self { return self }
    
    func cancel() { }
    }
