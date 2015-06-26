//
//  Resource.swift
//  Siesta
//
//  Created by Paul on 2015/6/16.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Alamofire

public class Resource
    {
    // Configuration
    
    public let service: Service
    public let url: NSURL? // TODO: figure out what to do about invalid URLs
    
    // Request management
    
    public var loading: Bool { return !requests.isEmpty }
    public private(set) var requests = Set<Request>()
    
    // Resource state

    public private(set) var latestData: Data?
    public private(set) var latestError: Error?
    public var data: AnyObject? { return latestData?.payload }
    public var timestamp: NSTimeInterval
        {
        return max(
            latestData?.timestamp ?? 0,
            latestError?.timestamp ?? 0)
        }
    
    init(service: Service, url: NSURL?)
        {
        self.service = service
        self.url = url?.absoluteURL
        }
    
    public func child(path: String) -> Resource
        {
        return service.resource(url?.URLByAppendingPathComponent(path))
        }
    
    public func relative(path: String) -> Resource
        {
        return service.resource(NSURL(string: path, relativeToURL: url))
        }
    
    public func request(
            method:          Alamofire.Method,
            requestMutation: NSMutableURLRequest -> () = { _ in })
        -> Request
        {
        let nsreq = NSMutableURLRequest(URL: url!)
        nsreq.HTTPMethod = method.rawValue
        requestMutation(nsreq)

        let request = service.sessionManager.request(nsreq)
        requests.insert(request)
        request.response
            {
            [weak self, weak request]
            _ in
            
            if let request = request
                { self?.requests.remove(request) }
            }
        return request
        }
    
    public func load() -> Request
        {
        return request(.GET)
                {
                nsreq in
                if let etag = self.latestData?.etag
                    { nsreq.setValue(etag, forHTTPHeaderField: "If-None-Match") }
                }
            .response
                {
                [weak self]
                nsreq, nsres, payload, error in
                
                if nsres?.statusCode >= 400 || error != nil
                    { self?.updateStateWithError(nsres, error, payload) }
                else if nsres?.statusCode == 304
                    { self?.updateStateWithDataNotModified() }
                else if let payload = payload
                    { self?.updateStateWithData(nsres, payload) }
                else
                    {} // TODO: how to handle empty success response?
                }
        }
    
    private func updateStateWithData(response: NSHTTPURLResponse?, _ payload: AnyObject)
        {
        self.latestError = nil
        self.latestData = Data(response, payload)
        }

    private func updateStateWithDataNotModified()
        {
        self.latestError = nil
        self.latestData?.touch()
        }
    
    private func updateStateWithError(
            response: NSHTTPURLResponse?,
            _ error: NSError?,
            _ payload: AnyObject?)
        {
        if let error = error
            where error.domain == "NSURLErrorDomain"
               && error.code == NSURLErrorCancelled
            { return }
        
        self.latestError = Error(response, payload, error)
        }
    
    public struct Data
        {
        public var payload: AnyObject // TODO: Can result transformer + generics fix AnyObject?
                                      // Probably service-wide default data type + per-resource override that requires “as?”
        public var mimeType: String
        public var etag: String?
        public private(set) var timestamp: NSTimeInterval = NSDate.timeIntervalSinceReferenceDate()
        
        public init(payload: AnyObject, mimeType: String, etag: String? = nil)
            {
            self.payload = payload
            self.mimeType = mimeType
            self.etag = etag
            self.timestamp = 0
            self.touch()
            }
        
        public init(_ response: NSHTTPURLResponse?, _ payload: AnyObject)
            {
            func header(key: String) -> String?
                { return response?.allHeaderFields[key] as? String }
            
            self.init(
                payload:  payload,
                mimeType: header("Content-Type") ?? "application/octet-stream",
                etag:     header("ETag"))
            }
        
        public mutating func touch()
            { timestamp = NSDate.timeIntervalSinceReferenceDate() }
        }

    public struct Error
        {
        public var httpStatusCode: Int?
        public var nsError: NSError?
        public var userMessage: String
        public var data: Data?
        public let timestamp: NSTimeInterval = NSDate.timeIntervalSinceReferenceDate()
        
        public init(
                _ response: NSHTTPURLResponse?,
                _ payload: AnyObject?,
                _ error: NSError?,
                userMessage: String? = nil)
            {
            self.httpStatusCode = response?.statusCode
            self.nsError = error
            
            if let payload = payload
                { self.data = Data(response, payload) }
            
            if let message = userMessage
                { self.userMessage = message }
            else if let message = error?.localizedDescription
                { self.userMessage = message }
            else if let code = self.httpStatusCode
                { self.userMessage = "Server error: \(NSHTTPURLResponse.localizedStringForStatusCode(code))" }
            else
                { self.userMessage = "Request failed" }   // Is this reachable?
            }
        }
    }

public func ==(lhs: Request, rhs: Request) -> Bool
    { return lhs === rhs }

extension Request: Hashable
    {
    public var hashValue: Int
        { return ObjectIdentifier(self).hashValue }
    }
