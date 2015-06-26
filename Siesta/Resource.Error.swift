//
//  Resource.Error.swift
//  Siesta
//
//  Created by Paul on 2015/6/26.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

extension Resource
    {
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
