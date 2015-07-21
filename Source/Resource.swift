//
//  Resource.swift
//  Siesta
//
//  Created by Paul on 2015/6/16.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Alamofire

// Overridable for testing
internal var now = { return NSDate.timeIntervalSinceReferenceDate() }

@objc(BOSResource)
public class Resource: CustomDebugStringConvertible
    {
    // MARK: Configuration
    
    public let service: Service
    public let url: NSURL? // TODO: figure out what to do about invalid URLs
    
    // MARK: Request management
    
    public var loading: Bool { return !loadRequests.isEmpty }
    public private(set) var loadRequests = [Request]()  // TOOD: How to handle concurrent POST & GET?
    
    public var expirationTime: NSTimeInterval?
    public var retryTime: NSTimeInterval?
    
    // MARK: Resource state

    public private(set) var latestData: Data?
    public private(set) var latestError: Error?
    public var timestamp: NSTimeInterval
        {
        return max(
            latestData?.timestamp ?? 0,
            latestError?.timestamp ?? 0)
        }
    
    // MARK: Data convenience accessors

    public var data: AnyObject? { return latestData?.payload }
    
    public func typedData<T>(blankValue: T) -> T
        {
        return (data as? T) ?? blankValue
        }
    
    public var dict:  [String:AnyObject] { return typedData([:]) }
    public var array: [AnyObject]        { return typedData([]) }
    public var text:  String             { return typedData("") }

    // MARK: Observers

    internal var observers = [ObserverEntry]()
    
    
    // MARK: -
    
    init(service: Service, url: NSURL?)
        {
        self.service = service
        self.url = url?.absoluteURL
        
        NSNotificationCenter.defaultCenter().addObserverForName(
                UIApplicationDidReceiveMemoryWarningNotification,
                object: nil,
                queue: nil)
            {
            [weak self] _ in
            self?.cleanDefunctObservers()
            }
        }
    
    // MARK: URL Navigation
    
    public func child(path: String) -> Resource
        {
        return service.resource(url?.URLByAppendingPathComponent(path))
        }
    
    public func relative(path: String) -> Resource
        {
        return service.resource(NSURL(string: path, relativeToURL: url))
        }
    
    public func optionalRelative(path: String?) -> Resource?
        {
        if let path = path
            { return relative(path) }
        else
            { return nil }
        }

    public func withParam(name: String, _ value: String?) -> Resource
        {
        return service.resource(
            url?.alterQuery
                {
                (var params) in
                params[name] = value
                return params
                })
        }
    
    // MARK: Requests
    
    public func request(
            method:          Alamofire.Method,
            requestMutation: NSMutableURLRequest -> () = { _ in })
        -> Request
        {
        let nsreq = NSMutableURLRequest(URL: url!)
        nsreq.HTTPMethod = method.rawValue
        requestMutation(nsreq)
        debugLog([nsreq.HTTPMethod, nsreq.URL])

        let alamoReq = service.sessionManager.request(nsreq)
            .response
                {
                nsreq, nsres, payload, nserror in
                debugLog([nsres?.statusCode, "←", nsreq?.HTTPMethod, nsreq?.URL])
                }
        return AlamofireSiestaRequest(resource: self, alamofireRequest: alamoReq)
        }
    
    public func request(
            method:          Alamofire.Method,
            data:            NSData,
            mimeType:        String,
            requestMutation: NSMutableURLRequest -> () = { _ in })
        -> Request
        {
        return request(method)
            {
            nsreq in
            
            nsreq.addValue(mimeType, forHTTPHeaderField: "Content-Type")
            nsreq.HTTPBody = data
            
            requestMutation(nsreq)
            }
        }
    
    public func request(
            method:          Alamofire.Method,
            text:            String,
            encoding:        NSStringEncoding = NSUTF8StringEncoding,
            requestMutation: NSMutableURLRequest -> () = { _ in })
        -> Request
        {
        let encodingName = CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(encoding))
        if let rawBody = text.dataUsingEncoding(encoding)
            { return request(method, data: rawBody, mimeType: "text/plain; charset=\(encodingName)") }
        else
            {
            return FailedRequest(
                Resource.Error(
                    userMessage: "Unable to encode text",
                    debugMessage: "Cannot encode text body using \(encodingName)"))
            }
        }

    public func request(
            method:          Alamofire.Method,
            json:            NSJSONConvertible,
            requestMutation: NSMutableURLRequest -> () = { _ in })
        -> Request
        {
        guard NSJSONSerialization.isValidJSONObject(json) else
            {
            return FailedRequest(
                Resource.Error(userMessage: "Cannot encode JSON", debugMessage: "Not a valid JSON object"))
            }
        
        do  {
            let rawBody = try NSJSONSerialization.dataWithJSONObject(json, options: [])
            return request(method, data: rawBody, mimeType: "application/json")
            }
        catch
            {
            // This catch block should obviate the isValidJSONObject() call above, but Swift apparently
            // doesn’t catch NSInvalidArgumentException (radar 21913397).
            return FailedRequest(
                Resource.Error(userMessage: "Cannot encode JSON", error: error as NSError))
            }
        }
    
    public func loadIfNeeded() -> Request?
        {
        if(loading)
            {
            debugLog([self, "loadIfNeeded(): is up to date; no need to load"])
            return nil  // TODO: should this return existing request instead?
            }
        
        let maxAge = (latestError == nil)
            ? expirationTime ?? service.defaultExpirationTime
            : retryTime      ?? service.defaultRetryTime
        
        if(now() - timestamp <= maxAge)
            {
            debugLog([self, "loadIfNeeded(): data still fresh for", maxAge - (now() - timestamp), "more seconds"])
            return nil
            }
        
        debugLog([self, "loadIfNeeded() triggered load()"])
        return self.load()
        }
    
    public func load() -> Request
        {
        let req = request(.GET)
            {
            nsreq in
            if let etag = self.latestData?.etag
                { nsreq.setValue(etag, forHTTPHeaderField: "If-None-Match") }
            }
        loadRequests.append(req)
        
        req.response
            {
            [weak self, weak req] _ in
            if let resource = self
                { resource.loadRequests = resource.loadRequests.filter { $0 !== req } }
            }
        req.newData(self.updateStateWithData)
        req.notModified(self.updateStateWithDataNotModified)
        req.error(self.updateStateWithError)

        self.notifyObservers(.Requested)

        return req
        }
    
    private func updateStateWithData(data: Data)
        {
        debugLog([self, "has new data:", data])
        
        self.latestError = nil
        self.latestData = data
        
        notifyObservers(.NewDataResponse)
        }

    private func updateStateWithDataNotModified()
        {
        debugLog([self, "existing data is still valid"])
        
        self.latestError = nil
        self.latestData?.touch()
        
        notifyObservers(.NotModifiedResponse)
        }
    
    private func updateStateWithError(error: Error)
        {
        if let nserror = error.nsError
            where nserror.domain == "NSURLErrorDomain"
               && nserror.code == NSURLErrorCancelled
            {
            notifyObservers(.RequestCancelled)
            return
            }

        debugLog([self, "received error:", error])
        
        self.latestError = error

        notifyObservers(.ErrorResponse)
        }
    
    // MARK: Debug
    
    public var debugDescription: String
        {
        return "Siesta.Resource("
            + debugStr(url)
            + ")["
            + (loading ? "L" : "")
            + (latestData != nil ? "D" : "")
            + (latestError != nil ? "E" : "")
            + "]"
        }
    }


/// For requests that failed before they even made it to the transport layer
private class FailedRequest: Request
    {
    private let error: Resource.Error
    
    init(_ error: Resource.Error)
        { self.error = error }
    
    func response(callback: AnyResponseCalback) -> Self
        {
        dispatch_async(dispatch_get_main_queue(), { callback(.ERROR(self.error)) })
        return self
        }
    
    func error(callback: ErrorCallback) -> Self
        {
        dispatch_async(dispatch_get_main_queue(), { callback(self.error) })
        return self
        }
    
    // Everything else is a noop
    
    func success(callback: SuccessCallback) -> Self { return self }
    func newData(callback: SuccessCallback) -> Self { return self }
    func notModified(callback: NotModifiedCallback) -> Self { return self }
    
    func cancel() { }
    }

public protocol NSJSONConvertible: AnyObject { }
extension NSDictionary: NSJSONConvertible { }
extension NSArray:      NSJSONConvertible { }
