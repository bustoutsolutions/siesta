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

// (Why not just make Entity and Error classes and avoid all these
// shenanigans? Because Swift’s lovely mutable/immutable struct handling lets Resource
// expose the full struct to Swift clients sans copying, yet still force mutations to
// happen via overrideLocalData() so that observers always know about changes.)

@objc(BOSEntity)
public class _objc_Entity: NSObject
    {
    public var content: AnyObject?
    public var contentType: String
    public var charset: String?
    public var etag: String?
    private var headers: [String:String]
    public private(set) var timestamp: NSTimeInterval = 0

    public init(content: AnyObject, contentType: String, headers: [String:String])
        {
        self.content = content
        self.contentType = contentType
        self.headers = headers
        }

    public convenience init(content: AnyObject, contentType: String)
        { self.init(content: content, contentType: contentType, headers: [:]) }

    internal init(_ entity: Entity)
        {
        if !(entity.content is AnyObject)
            {
            NSLog("WARNING: entity content of type \(entity.content.dynamicType)"
                + " is not an object, and therefore not usable from Objective-C")
            }

        self.content     = entity.content as? AnyObject
        self.contentType = entity.contentType
        self.charset     = entity.charset
        self.etag        = entity.etag
        self.headers     = entity.headers
        }

    public func header(key: String) -> String?
        { return headers[key.lowercaseString] }

    public override var description: String
        { return debugStr(Entity(entity: self)) }
    }

internal extension Entity
    {
    init(entity: _objc_Entity)
        {
        self.init(content: entity.content, contentType: entity.contentType, charset: entity.charset, headers: entity.headers)
        }
    }

@objc(BOSError)
public class _objc_Error: NSObject
    {
    public var httpStatusCode: Int
    public var cause: NSError?
    public var userMessage: String
    public var entity: _objc_Entity?
    public let timestamp: NSTimeInterval

    internal init(_ error: Error)
        {
        self.httpStatusCode = error.httpStatusCode ?? -1
        self.cause          = error.cause as? NSError
        self.userMessage    = error.userMessage
        self.timestamp      = error.timestamp
        if let errorData = error.entity
            { self.entity = _objc_Entity(errorData) }
        }
    }

public extension Service
    {
    @objc(resourceWithAbsoluteURL:)
    public final func _objc_resourceWithAbsoluteURL(absoluteURL url: NSURL?) -> Resource
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
    public var _objc_jsonDict: [String:AnyObject]
        { return jsonDict }

    @objc(jsonArray)
    public var _objc_jsonArray: [AnyObject]
        { return jsonArray }

    @objc(text)
    public var _objc_text: String
        { return text }

    @objc(overrideLocalData:)
    public func _objc_overrideLocalData(entity: _objc_Entity)
        { overrideLocalData(Entity(entity: entity)) }
    }

// MARK: - Because Swift closures aren’t exposed as Obj-C blocks

@objc(BOSRequest)
public class _objc_Request: NSObject
    {
    private let request: Request

    private init(_ request: Request)
        { self.request = request }

    public func onCompletion(objcCallback: @convention(block) (_objc_Entity?, _objc_Error?) -> Void) -> _objc_Request
        {
        request.onCompletion
            {
            switch $0
                {
                case .Success(let entity):
                    objcCallback(_objc_Entity(entity), nil)
                case .Failure(let error):
                    objcCallback(nil, _objc_Error(error))
                }
            }
        return self
        }

    public func onSuccess(objcCallback: @convention(block) _objc_Entity -> Void) -> _objc_Request
        {
        request.onSuccess { entity in objcCallback(_objc_Entity(entity)) }
        return self
        }

    public func onNewData(objcCallback: @convention(block) _objc_Entity -> Void) -> _objc_Request
        {
        request.onNewData { entity in objcCallback(_objc_Entity(entity)) }
        return self
        }

    public func onNotModified(objcCallback: @convention(block) Void -> Void) -> _objc_Request
        {
        request.onNotModified(objcCallback)
        return self
        }

    public func onFailure(objcCallback: @convention(block) _objc_Error -> Void) -> _objc_Request
        {
        request.onFailure { error in objcCallback(_objc_Error(error)) }
        return self
        }

    public func onProgress(objcCallback: @convention(block) Float -> Void) -> _objc_Request
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
    func resourceChanged(resource: Resource, event: String)
    optional func resourceRequestProgress(resource: Resource, progress: Double)
    optional func stoppedObservingResource(resource: Resource)
    }

private class _objc_ResourceObserverGlue: ResourceObserver, CustomDebugStringConvertible
    {
    weak var objcObserver: _objc_ResourceObserver?

    init(objcObserver: _objc_ResourceObserver)
        { self.objcObserver = objcObserver }

    func resourceChanged(resource: Resource, event: ResourceEvent)
        { objcObserver?.resourceChanged(resource, event: event.description) }

    func resourceRequestProgress(resource: Resource, progress: Double)
        { objcObserver?.resourceRequestProgress?(resource, progress: progress) }

    func stoppedObservingResource(resource: Resource)
        { objcObserver?.stoppedObservingResource?(resource) }

    var debugDescription: String
        {
        if objcObserver != nil
            { return debugStr(objcObserver) }
        else
            { return "_objc_ResourceObserverGlue<deallocated delegate>" }
        }

    func isEquivalentToObserver(other: ResourceObserver) -> Bool
        {
        if let otherGlue = (other as? _objc_ResourceObserverGlue)
            { return self.objcObserver === otherGlue.objcObserver }
        else
            { return false }
        }
    }

public extension Resource
    {
    @objc(addObserver:)
    public func _objc_addObserver(observerAndOwner: protocol<_objc_ResourceObserver, AnyObject>) -> Self
        { return addObserver(_objc_ResourceObserverGlue(objcObserver: observerAndOwner), owner: observerAndOwner) }

    @objc(addObserver:owner:)
    public func _objc_addObserver(objcObserver: _objc_ResourceObserver, owner: AnyObject) -> Self
        { return addObserver(_objc_ResourceObserverGlue(objcObserver: objcObserver), owner: owner) }

    @objc(addObserverWithOwner:callback:)
    public func _objc_addObserver(owner owner: AnyObject, block: @convention(block) (Resource,String) -> Void) -> Self
        {
        return addObserver(owner: owner)
            { block($0, $1.description) }
        }
    }

#if !os(OSX)
extension ResourceStatusOverlay: _objc_ResourceObserver
    {
    public func resourceChanged(resource: Resource, event eventString: String)
        {
        if let event = ResourceEvent.fromDescription(eventString)
            { resourceChanged(resource, event: event) }
        }
    }

extension ResourceStatusOverlay
    {
    @objc(displayPriority)
    public var _objc_displayPriority: [String]
        {
        get {
            return displayPriority.map { $0.rawValue }
            }

        set {
            displayPriority = newValue.flatMap
                {
                let condition = ResourceStatusOverlay.StateRule(rawValue: $0)
                if condition == nil
                    { Swift.print("WARNING: ignoring unknown ResourceStatusOverlay.StateRule \"\($0)\"") }
                return condition
                }
            }
        }
    }
#endif

public extension Resource
    {
    private func _objc_wrapRequest(
            methodString: String,
            @noescape closure: RequestMethod -> Request)
        -> _objc_Request
        {
        guard let method = RequestMethod(rawValue: methodString) else
            {
            return _objc_Request(
                Resource.failedRequest(
                    Error(
                        userMessage: NSLocalizedString("Cannot create request", comment: "userMessage"),
                        cause: _objc_Error.Cause.InvalidRequestMethod(method: methodString))))
            }

        return _objc_Request(closure(method))
        }

    private func _objc_wrapJSONRequest(
            methodString: String,
            _ maybeJson: NSObject?,
            @noescape closure: (RequestMethod, NSJSONConvertible) -> Request)
        -> _objc_Request
        {
        guard let json = maybeJson as? NSJSONConvertible else
            {
            return _objc_Request(
                Resource.failedRequest(
                    Error(
                        userMessage: NSLocalizedString("Cannot send request", comment: "userMessage"),
                        cause: Error.Cause.InvalidJSONObject())))
            }

        return _objc_wrapRequest(methodString) { closure($0, json) }
        }

    @objc(requestWithMethod:requestMutation:)
    public func _objc_request(
            method:          String,
            requestMutation: (@convention(block) NSMutableURLRequest -> ())?)
        -> _objc_Request
        {
        return _objc_wrapRequest(method)
            {
            request($0)
                { requestMutation?($0) }
            }
        }

    @objc(requestWithMethod:)
    public func _objc_request(method: String)
        -> _objc_Request
        {
        return _objc_wrapRequest(method)
            { request($0) }
        }

    @objc(requestWithMethod:data:contentType:requestMutation:)
    public func _objc_request(
            method:          String,
            data:            NSData,
            contentType:     String,
            requestMutation: (@convention(block) NSMutableURLRequest -> ())?)
        -> _objc_Request
        {
        return _objc_wrapRequest(method)
            {
            request($0, data: data, contentType: contentType)
                { requestMutation?($0) }
            }
        }

     @objc(requestWithMethod:text:)
     public func _objc_request(
             method:          String,
             text:            String)
         -> _objc_Request
         {
         return _objc_wrapRequest(method)
            { request($0, text: text) }
         }

     @objc(requestWithMethod:text:contentType:encoding:requestMutation:)
     public func _objc_request(
             method:          String,
             text:            String,
             contentType:     String,
             encoding:        NSStringEncoding = NSUTF8StringEncoding,
             requestMutation: (@convention(block) NSMutableURLRequest -> ())?)
         -> _objc_Request
         {
         return _objc_wrapRequest(method)
            {
            request($0, text: text, contentType: contentType, encoding: encoding)
                { requestMutation?($0) }
            }
         }

     @objc(requestWithMethod:json:)
     public func _objc_request(
             method:          String,
             json:            NSObject?)
         -> _objc_Request
         {
         return _objc_wrapJSONRequest(method, json)
            { request($0, json: $1) }
         }

     @objc(requestWithMethod:json:contentType:requestMutation:)
     public func _objc_request(
             method:          String,
             json:            NSObject?,
             contentType:     String,
             requestMutation: (@convention(block) NSMutableURLRequest -> ())?)
         -> _objc_Request
         {
         return _objc_wrapJSONRequest(method, json)
            {
            request($0, json: $1, contentType: contentType)
                { requestMutation?($0) }
            }
         }

     @objc(requestWithMethod:urlEncoded:requestMutation:)
     public func _objc_request(
             method:            String,
             urlEncoded params: [String:String],
             requestMutation:   (@convention(block) NSMutableURLRequest -> ())?)
         -> _objc_Request
         {
         return _objc_wrapRequest(method)
            {
            request($0, urlEncoded: params)
                { requestMutation?($0) }
            }
         }

    @objc(loadUsingRequest:)
    public func _objc_load(usingRequest req: _objc_Request) -> _objc_Request
        {
        load(usingRequest: req.request)
        return req
        }
    }

public extension _objc_Error
    {
    public enum Cause
        {
        /// Request method specified as a string does not match any of the values in the RequestMethod enum.
        public struct InvalidRequestMethod: ErrorType
            {
            public let method: String
            }
        }
    }
