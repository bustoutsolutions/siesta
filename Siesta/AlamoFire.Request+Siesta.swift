//
//  AlamoFire.Request+Siesta.swift
//  Siesta
//
//  Created by Paul on 2015/6/26.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Alamofire

public func ==(lhs: Request, rhs: Request) -> Bool
    { return lhs === rhs }

extension Request: Hashable
    {
    public var hashValue: Int
        { return ObjectIdentifier(self).hashValue }
    }

public extension Request
    {
    public func resourceResponse(
            resource:    Resource,
            success:     Resource.Data -> Void = { _ in },
            notModified: (Void -> Void)? = nil,
            error:       Resource.Error -> Void = { _ in })
        -> Self
        {
        response
            {
            nsreq, nsres, payload, nserror in
            
            if nsres?.statusCode >= 400 || nserror != nil
                {
                error(Resource.Error(nsres, payload, nserror))
                }
            else if nsres?.statusCode == 304
                {
                if let notModified = notModified
                    { notModified() }
                else if let existingData = resource.latestData
                    { success(existingData) }
                else
                    { } // TODO: Handle 304 but no existing data
                }
            else if let payload = payload
                {
                success(Resource.Data(nsres, payload))
                }
            else
                { } // TODO: how to handle empty success response?
            }
        return self
        }
    }
