//
//  Resource.Data.swift
//  Siesta
//
//  Created by Paul on 2015/6/26.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

extension Resource
    {
    public struct Data
        {
        public var payload: AnyObject // TODO: Can result transformer + generics fix AnyObject?
                                      // Probably service-wide default data type + per-resource override that requires “as?”
        public var mimeType: String
        public var charset: String?
        public var etag: String?
        public private(set) var timestamp: NSTimeInterval = 0
        
        public init(payload: AnyObject, mimeType: String, charset: String? = nil, etag: String? = nil)
            {
            self.payload = payload
            self.mimeType = mimeType
            self.charset = charset
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
                charset:  response?.textEncodingName,
                etag:     header("ETag"))
            }
        
        public mutating func touch()
            { timestamp = now() }
        }
    }
