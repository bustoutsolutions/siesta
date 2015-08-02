//
//  ResourceError.swift
//  Siesta
//
//  Created by Paul on 2015/6/26.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

public struct ResourceError
    {
    public var httpStatusCode: Int?
    public var nsError: NSError?
    public var userMessage: String
    public var data: ResourceData?
    public let timestamp: NSTimeInterval = now()
    
    public init(
            _ response: NSHTTPURLResponse?,
            _ payload: AnyObject?,
            _ error: NSError?,
            userMessage: String? = nil)
        {
        self.httpStatusCode = response?.statusCode
        self.nsError = error
        
        if let payload = payload
            { self.data = ResourceData(response, payload) }
        
        if let message = userMessage
            { self.userMessage = message }
        else if let message = error?.localizedDescription
            { self.userMessage = message }
        else if let code = self.httpStatusCode
            { self.userMessage = NSHTTPURLResponse.localizedStringForStatusCode(code).capitalizedFirstCharacter }
        else
            { self.userMessage = "Request failed" }   // Is this reachable?
        }
    
    public init(
            userMessage: String,
            error: NSError? = nil,
            httpStatusCode: Int? = nil,
            data: ResourceData? = nil)
        {
        self.userMessage = userMessage
        self.nsError = error
        self.httpStatusCode = httpStatusCode
        self.data = data
        }

    public init(
            userMessage: String,
            debugMessage: String,
            data: ResourceData? = nil)
        {
        let nserror = NSError(domain: "Siesta", code: -1, userInfo: [NSLocalizedDescriptionKey: debugMessage])
        self.init(userMessage: userMessage, error: nserror, data: data)
        }
    }
