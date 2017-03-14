//
//  Siesta-ObjC.swift
//  Siesta
//
//  Created by Paul on 2015/7/14.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

/*
    Glue for using Siesta from Objective-C.

    Siesta follows a Swift-first design approach. It uses the full expressiveness of the
    language to make everything feel “Swift native,” both in interface and implementation.

    This means many Siesta APIs can’t simply be marked @objc, and require a separate
    compatibility layer. Rather than sprinkle that mess throughout the code, it’s all
    quarrantined here.

    Features exposed to Objective-C:

     * Resource path navigation (child, relative, etc.)
     * Resource state
     * Observers
     * Request / load
     * Request completion callbacks
     * UI components

    Some things are not exposed in the compatibility layer, and must be done in Swift:

     * Subclassing Service
     * Custom ResponseTransformers
     * Custom NetworkingProviders
     * Logging config
*/

// MARK: - Because Swift structs aren’t visible to Obj-C

// (Why not just make Entity<Any> and RequestError classes and avoid all these
// shenanigans? Because Swift’s lovely mutable/immutable struct handling lets Resource
// expose the full struct to Swift clients sans copying, yet still force mutations to
// happen via overrideLocalData() so that observers always know about changes.)

@objc(BOSEntity)
public class _objc_Entity: NSObject
    {
    public var content: AnyObject
    public var contentType: String
    public var charset: String?
    public var etag: String?
    fileprivate var headers: [String:String]
    public private(set) var timestamp: TimeInterval = 0

    public init(content: AnyObject, contentType: String, headers: [String:String])
        {
        self.content = content
        self.contentType = contentType
        self.headers = headers
        }

    public convenience init(content: AnyObject, contentType: String)
        { self.init(content: content, contentType: contentType, headers: [:]) }

    internal init(_ entity: Entity<Any>)
        {
        self.content     = entity.content as AnyObject
        self.contentType = entity.contentType
        self.charset     = entity.charset
        self.etag        = entity.etag
        self.headers     = entity.headers
        }

    public func header(_ key: String) -> String?
        { return headers[key.lowercased()] }

    public override var description: String
        { return debugStr(Entity<Any>.convertedFromObjc(self)) }
    }

internal extension Entity
    {
    static func convertedFromObjc(_ entity: _objc_Entity) -> Entity<Any>
        {
        return Entity<Any>(content: entity.content, contentType: entity.contentType, charset: entity.charset, headers: entity.headers)
        }
    }

@objc(BOSError)
public class _objc_Error: NSObject
    {
    public var httpStatusCode: Int
    public var cause: NSError?
    public var userMessage: String
    public var entity: _objc_Entity?
    public let timestamp: TimeInterval

    internal init(_ error: RequestError)
        {
        self.httpStatusCode = error.httpStatusCode ?? -1
        self.cause          = error.cause as NSError?
        self.userMessage    = error.userMessage
        self.timestamp      = error.timestamp
        if let errorData = error.entity
            { self.entity = _objc_Entity(errorData) }
        }
    }

public extension Service
    {
    @objc(resourceWithAbsoluteURL:)
    public final func _objc_resourceWithAbsoluteURL(absoluteURL url: URL?) -> Resource
        { return resource(absoluteURL: url) }

    @objc(resourceWithAbsoluteURLString:)
    public final func _objc_resourceWithAbsoluteURLString(absoluteURL url: String?) -> Resource
        { return resource(absoluteURL: url) }
    }

public extension Resource
    {
    @objc(latestData)
    public var _objc_latestData: _objc_Entity?
        {
        if let latestData = latestData
            { return _objc_Entity(latestData) }
        else
            { return nil }
        }

    @objc(latestError)
    public var _objc_latestError: _objc_Error?
        {
        if let latestError = latestError
            { return _objc_Error(latestError) }
        else
            { return nil }
        }

    @objc(jsonDict)
    public var _objc_jsonDict: NSDictionary
        { return jsonDict as NSDictionary }

    @objc(jsonArray)
    public var _objc_jsonArray: NSArray
        { return jsonArray as NSArray }

    @objc(text)
    public var _objc_text: String
        { return text }

    @objc(overrideLocalData:)
    public func _objc_overrideLocalData(_ entity: _objc_Entity)
        { overrideLocalData(with: Entity<Any>.convertedFromObjc(entity)) }
    }

// MARK: - Because Swift closures aren’t exposed as Obj-C blocks

@objc(BOSRequest)
public class _objc_Request: NSObject
    {
    fileprivate let request: Request

    fileprivate init(_ request: Request)
        { self.request = request }

    public func onCompletion(_ objcCallback: @escaping @convention(block) (_objc_Entity?, _objc_Error?) -> Void) -> _objc_Request
        {
        request.onCompletion
            {
            switch $0.response
                {
                case .success(let entity):
                    objcCallback(_objc_Entity(entity), nil)

                case .failure(let error):
                    objcCallback(nil, _objc_Error(error))
                }
            }
        return self
        }

    public func onSuccess(_ objcCallback: @escaping @convention(block) (_objc_Entity) -> Void) -> _objc_Request
        {
        request.onSuccess { entity in objcCallback(_objc_Entity(entity)) }
        return self
        }

    public func onNewData(_ objcCallback: @escaping @convention(block) (_objc_Entity) -> Void) -> _objc_Request
        {
        request.onNewData { entity in objcCallback(_objc_Entity(entity)) }
        return self
        }

    public func onNotModified(_ objcCallback: @escaping @convention(block) (Void) -> Void) -> _objc_Request
        {
        request.onNotModified(objcCallback)
        return self
        }

    public func onFailure(_ objcCallback: @escaping @convention(block) (_objc_Error) -> Void) -> _objc_Request
        {
        request.onFailure { error in objcCallback(_objc_Error(error)) }
        return self
        }

    public func onProgress(_ objcCallback: @escaping @convention(block) (Float) -> Void) -> _objc_Request
        {
        request.onProgress { p in objcCallback(Float(p)) }
        return self
        }

    public func cancel()
        { request.cancel() }

    public override var description: String
        { return debugStr(request) }
    }

public extension Resource
    {
    @objc(load)
    public func _objc_load() -> _objc_Request
        { return _objc_Request(load()) }

    @objc(loadIfNeeded)
    public func _objc_loadIfNeeded() -> _objc_Request?
        {
        if let req = loadIfNeeded()
            { return _objc_Request(req) }
        else
            { return nil }
        }
    }

// MARK: - Because Swift enums aren’t exposed to Obj-C

@objc(BOSResourceObserver)
public protocol _objc_ResourceObserver
    {
    func resourceChanged(_ resource: Resource, event: String)
    @objc optional func resourceRequestProgress(_ resource: Resource, progress: Double)
    @objc optional func stoppedObservingResource(_ resource: Resource)
    }

private class _objc_ResourceObserverGlue: ResourceObserver, CustomDebugStringConvertible
    {
    var resource: Resource?
    var objcObserver: _objc_ResourceObserver

    init(objcObserver: _objc_ResourceObserver)
        { self.objcObserver = objcObserver }

    deinit
        {
        if let resource = resource
            { objcObserver.stoppedObservingResource?(resource) }
        }

    func resourceChanged(_ resource: Resource, event: ResourceEvent)
        {
        if case .observerAdded = event
            { self.resource = resource }
        objcObserver.resourceChanged(resource, event: event._objc_stringForm)
        }

    func resourceRequestProgress(_ resource: Resource, progress: Double)
        { objcObserver.resourceRequestProgress?(resource, progress: progress) }

    var observerIdentity: AnyHashable
        { return ObjectIdentifier(objcObserver) }

    var debugDescription: String
        { return debugStr(objcObserver) }
    }

extension ResourceEvent
    {
    public var _objc_stringForm: String
        {
        if case .newData(let source) = self
            { return "NewData(\(source.description.capitalized))" }
        else
            { return String(describing: self).capitalized }
        }
    }

public extension Resource
    {
    @objc(addObserver:)
    public func _objc_addObserver(_ observerAndOwner: _objc_ResourceObserver & AnyObject) -> Self
        { return addObserver(_objc_ResourceObserverGlue(objcObserver: observerAndOwner), owner: observerAndOwner) }

    @objc(addObserver:owner:)
    public func _objc_addObserver(_ objcObserver: _objc_ResourceObserver, owner: AnyObject) -> Self
        { return addObserver(_objc_ResourceObserverGlue(objcObserver: objcObserver), owner: owner) }

    @objc(addObserverWithOwner:callback:)
    public func _objc_addObserver(owner: AnyObject, block: @escaping @convention(block) (Resource, String) -> Void) -> Self
        {
        return addObserver(owner: owner)
            { block($0, $1._objc_stringForm) }
        }
    }

public extension Resource
    {
    private func _objc_wrapRequest(
            _ methodString: String,
            closure: (RequestMethod) -> Request)
        -> _objc_Request
        {
        guard let method = RequestMethod(rawValue: methodString.lowercased()) else
            {
            return _objc_Request(
                Resource.failedRequest(
                    RequestError(
                        userMessage: NSLocalizedString("Cannot create request", comment: "userMessage"),
                        cause: _objc_Error.Cause.InvalidRequestMethod(method: methodString))))
            }

        return _objc_Request(closure(method))
        }

    private func _objc_wrapJSONRequest(
            _ methodString: String,
            _ maybeJson: NSObject?,
            closure: (RequestMethod, JSONConvertible) -> Request)
        -> _objc_Request
        {
        guard let json = maybeJson as? JSONConvertible else
            {
            return _objc_Request(
                Resource.failedRequest(
                    RequestError(
                        userMessage: NSLocalizedString("Cannot send request", comment: "userMessage"),
                        cause: RequestError.Cause.InvalidJSONObject())))
            }

        return _objc_wrapRequest(methodString) { closure($0, json) }
        }

    private static func apply(requestMutation: (@convention(block) (NSMutableURLRequest) -> ())?, to request: inout URLRequest)
        {
        let mutableReq = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        requestMutation?(mutableReq)
        request = mutableReq as URLRequest
        }

    @objc(requestWithMethod:requestMutation:)
    public func _objc_request(
            _ method:          String,
            requestMutation: (@convention(block) (NSMutableURLRequest) -> ())?)
        -> _objc_Request
        {
        return _objc_wrapRequest(method)
            {
            request($0)
                { Resource.apply(requestMutation: requestMutation, to: &$0) }
            }
        }

    @objc(requestWithMethod:)
    public func _objc_request(_ method: String)
        -> _objc_Request
        {
        return _objc_wrapRequest(method)
            { request($0) }
        }

    @objc(requestWithMethod:data:contentType:requestMutation:)
    public func _objc_request(
            _ method:        String,
            data:            Data,
            contentType:     String,
            requestMutation: (@convention(block) (NSMutableURLRequest) -> ())?)
        -> _objc_Request
        {
        return _objc_wrapRequest(method)
            {
            request($0, data: data, contentType: contentType)
                { Resource.apply(requestMutation: requestMutation, to: &$0) }
            }
        }

     @objc(requestWithMethod:text:)
     public func _objc_request(
             _ method:        String,
             text:            String)
         -> _objc_Request
         {
         return _objc_wrapRequest(method)
            { request($0, text: text) }
         }

     @objc(requestWithMethod:text:contentType:encoding:requestMutation:)
     public func _objc_request(
             _ method:        String,
             text:            String,
             contentType:     String,
             encoding:        UInt = String.Encoding.utf8.rawValue,
             requestMutation: (@convention(block) (NSMutableURLRequest) -> ())?)
         -> _objc_Request
         {
         return _objc_wrapRequest(method)
            {
            request($0, text: text, contentType: contentType, encoding: String.Encoding(rawValue: encoding))
                { Resource.apply(requestMutation: requestMutation, to: &$0) }
            }
         }

     @objc(requestWithMethod:json:)
     public func _objc_request(
             _ method:        String,
             json:            NSObject?)
         -> _objc_Request
         {
         return _objc_wrapJSONRequest(method, json)
            { request($0, json: $1) }
         }

     @objc(requestWithMethod:json:contentType:requestMutation:)
     public func _objc_request(
             _ method:        String,
             json:            NSObject?,
             contentType:     String,
             requestMutation: (@convention(block) (NSMutableURLRequest) -> ())?)
         -> _objc_Request
         {
         return _objc_wrapJSONRequest(method, json)
            {
            request($0, json: $1, contentType: contentType)
                { Resource.apply(requestMutation: requestMutation, to: &$0) }
            }
         }

     @objc(requestWithMethod:urlEncoded:requestMutation:)
     public func _objc_request(
             _ method:          String,
             urlEncoded params: [String:String],
             requestMutation:   (@convention(block) (NSMutableURLRequest) -> ())?)
         -> _objc_Request
         {
         return _objc_wrapRequest(method)
            {
            request($0, urlEncoded: params)
                { Resource.apply(requestMutation: requestMutation, to: &$0) }
            }
         }

    @objc(loadUsingRequest:)
    public func _objc_load(using req: _objc_Request) -> _objc_Request
        {
        load(using: req.request)
        return req
        }
    }

public extension _objc_Error
    {
    public enum Cause
        {
        /// Request method specified as a string does not match any of the values in the RequestMethod enum.
        public struct InvalidRequestMethod: Error
            {
            public let method: String
            }
        }
    }
