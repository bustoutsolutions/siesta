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
                nsreq, nsres, data, error in
                
                if nsres?.statusCode >= 400
                    { self?.updateStateWithHttpError(nsres) }
                else if nsres?.statusCode == 304
                    { self?.updateStateWithDataNotModified() }
                else if let error = error
                    { self?.updateStateWithNSError(error, response: nsres) }
                else if let data = data
                    { self?.updateStateWithData(data, response: nsres) }
                }
        }
    
    private func updateStateWithData(data: AnyObject, response: NSHTTPURLResponse?)
        {
        func header(key: String) -> String?
            { return response?.allHeaderFields[key] as? String }
        
        self.latestError = nil
        self.latestData = Data(
            payload:  data,
            mimeType: header("Content-Type") ?? "application/octet-stream",
            etag:     header("ETag"))
        }

    private func updateStateWithDataNotModified()
        {
        self.latestError = nil
        self.latestData?.touch()
        }
    
    private func updateStateWithHttpError(response: NSHTTPURLResponse?)
        {
        self.latestError = Error()
        self.latestError?.httpStatusCode = response?.statusCode
        }
    
    private func updateStateWithNSError(error: NSError, response: NSHTTPURLResponse?)
        {
        if error.domain == "NSURLErrorDomain" && error.code == NSURLErrorCancelled
            { return }
        
        self.latestError = Error()
        self.latestError?.nsError = error
        }
    
    public struct Data
        {
        public var payload: AnyObject // TODO: Can result transformer + generics fix AnyObject?
                                      // Probably service-wide default data type + per-resource override that requires “as?”
        public var mimeType: String
        public var etag: String?
        public var timestamp: NSTimeInterval = NSDate.timeIntervalSinceReferenceDate()
        
        public init(payload: AnyObject, mimeType: String, etag: String? = nil)
            {
            self.payload = payload
            self.mimeType = mimeType
            self.etag = etag
            self.timestamp = 0
            self.touch()
            }
        
        public mutating func touch()
            { timestamp = NSDate.timeIntervalSinceReferenceDate() }
        }

    public struct Error
        {
        public var httpStatusCode: Int?
        public var nsError: NSError?
//        public var payload: AnyObject
        public let timestamp: NSTimeInterval = NSDate.timeIntervalSinceReferenceDate()
        }
    }

public func ==(lhs: Request, rhs: Request) -> Bool
    { return lhs === rhs }

extension Request: Hashable
    {
    public var hashValue: Int
        { return ObjectIdentifier(self).hashValue }
    }
