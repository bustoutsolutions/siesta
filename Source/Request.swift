//
//  Request.swift
//  Siesta
//
//  Created by Paul on 2015/7/20.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

public typealias AnyResponseCalback = (Siesta.Response, NSURLResponse?) -> Void
public typealias SuccessCallback = (Resource.Data, NSURLResponse?) -> Void
public typealias NotModifiedCallback = NSURLResponse? -> Void
public typealias ErrorCallback = (Resource.Error, NSURLResponse?) -> Void

public protocol Request: AnyObject
    {
    func response(callback: AnyResponseCalback) -> Self      // success or failure
    func success(callback: SuccessCallback) -> Self          // success, may be same data
    func newData(callback: SuccessCallback) -> Self          // success, data modified
    func notModified(callback: NotModifiedCallback) -> Self  // success, data not modified
    func error(callback: ErrorCallback) -> Self              // failure
    
    func cancel()
    }

