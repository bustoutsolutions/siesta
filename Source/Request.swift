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

public typealias AnyResponseCalback = Response -> Void
public typealias SuccessCallback = Resource.Data -> Void
public typealias NotModifiedCallback = Void -> Void
public typealias ErrorCallback = Resource.Error -> Void

public protocol Request: AnyObject
    {
    func response(callback: AnyResponseCalback) -> Self      // success or failure
    func success(callback: SuccessCallback) -> Self          // success, may be same data
    func newData(callback: SuccessCallback) -> Self          // success, data modified
    func notModified(callback: NotModifiedCallback) -> Self  // success, data not modified
    func failure(callback: ErrorCallback) -> Self            // error of any kind
    
    func cancel()
    }

public enum Response: CustomStringConvertible
    {
    case Success(Resource.Data)
    case Failure(Resource.Error)
    
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

public class AbstractRequest: Request
    {
    public let resource: Resource
    
    private var responseCallbacks: [ResponseCallback] = []

    init(resource: Resource)
        {
        self.resource = resource
        }
    
    public func handleResponse(nsreq: NSURLRequest?, nsres: NSHTTPURLResponse?, body: NSData?, nserror: NSError?)
        {
        let responseInfo = interpretResponse(nsres, body, nserror)
        
        debugLog(.NetworkDetails, ["Raw response:", responseInfo.response])
        
        processPayload(responseInfo)
            {
            for callback in self.responseCallbacks
                { callback($0) }
            }
        }
    
    private func interpretResponse(nsres: NSHTTPURLResponse?, _ body: NSData?, _ nserror: NSError?)
        -> ResponseInfo
        {
        if nsres?.statusCode >= 400 || nserror != nil
            {
            return (.Failure(Resource.Error(nsres, body, nserror)), true)
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
                    .Failure(Resource.Error(
                        userMessage: "No data",
                        debugMessage: "Received HTTP 304, but resource has no existing data")),
                    true)
                }
            }
        else if let body = body
            {
            return (.Success(Resource.Data(nsres, body)), true)
            }
        else
            {
            return (.Failure(Resource.Error(userMessage: "Empty response")), true)
            }
        }
    
    private func processPayload(rawInfo: ResponseInfo, callback: ResponseCallback)
        {
        let transformer = resource.service.responseTransformers
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0))
            {
            let processedInfo =
                rawInfo.isNew
                    ? (transformer.process(rawInfo.response), true)
                    : rawInfo
            
            dispatch_async(dispatch_get_main_queue())
                { callback(processedInfo) }
            }
        }
    
    // MARK: Callbacks

    public func cancel()
        {
        fatalError("subclass must implement cancel()")
        }
    
    public func response(callback: AnyResponseCalback) -> Self
        {
        addResponseCallback
            {
            response, _ in
            callback(response)
            }
        return self
        }
    
    public func success(callback: SuccessCallback) -> Self
        {
        addResponseCallback
            {
            response, _ in
            if case .Success(let data) = response
                { callback(data) }
            }
        return self
        }
    
    public func newData(callback: SuccessCallback) -> Self
        {
        addResponseCallback
            {
            response, isNew in
            if case .Success(let data) = response where isNew
                { callback(data) }
            }
        return self
        }
    
    public func notModified(callback: NotModifiedCallback) -> Self
        {
        addResponseCallback
            {
            response, isNew in
            if case .Success = response where !isNew
                { callback() }
            }
        return self
        }
    
    public func failure(callback: ErrorCallback) -> Self
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
    }
