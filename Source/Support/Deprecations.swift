//
//  Deprecations.swift
//  Siesta
//
//  Created by Paul on 2015/12/12.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//


import Foundation

// MARK: - Deprecated in beta 7

extension Resource
    {
    @available(*, deprecated=0.99, message="This property is going away from the public API. If you have a need for it, please file a Github issue describing your use case.")
    public var config: Configuration
        { return generalConfig }
    }

// MARK: - Deprecated in beta 6

extension Entity
    {
    @available(*, deprecated=0.99, renamed="Entity(response:content:)")
    public init(_ response: NSHTTPURLResponse?, _ content: Any)
        { self.init(response: response, content: content) }
    }

extension Error
    {
    @available(*, deprecated=0.99, renamed="Error(response:content:cause:userMessage:)")
    public init(
            _ response: NSHTTPURLResponse?,
            _ content: AnyObject?,
            _ cause: ErrorType?,
            userMessage: String? = nil)
        { self.init(response: response, content: content, cause: cause, userMessage: userMessage) }
    }

extension Resource
    {
    @available(*, deprecated=0.99, renamed="isLoading")
    public var loading: Bool
        { return isLoading }

    @available(*, deprecated=0.99, renamed="isRequesting")
    public var requesting: Bool
        { return isRequesting }

    @available(*, deprecated=0.99, renamed="overrideLocalData")
    public func localDataOverride(entity: Entity)
        { overrideLocalData(entity) }

    @available(*, deprecated=0.99, renamed="overrideLocalContent")
    public func localContentOverride(content: AnyObject)
        { overrideLocalContent(content) }
    }

extension Request
    {
    @available(*, deprecated=0.99, renamed="isCompleted")
    public var completed: Bool
        { return isCompleted }

    @available(*, deprecated=0.99, renamed="onCompletion")
    public func completion(callback: Response -> Void) -> Self
        { return onCompletion(callback) }

    @available(*, deprecated=0.99, renamed="onSuccess")
    public func success(callback: Entity -> Void) -> Self
        { return onSuccess(callback) }

    @available(*, deprecated=0.99, renamed="onNewData")
    public func newData(callback: Entity -> Void) -> Self
        { return onNewData(callback) }

    @available(*, deprecated=0.99, renamed="onNotModified")
    public func notModified(callback: Void -> Void) -> Self
        { return onNotModified(callback) }

    @available(*, deprecated=0.99, renamed="onFailure")
    public func failure(callback: Error -> Void) -> Self
        { return onFailure(callback) }

    @available(*, deprecated=0.99, renamed="onProgress")
    public func progress(callback: Double -> Void) -> Self
        { return onProgress(callback) }

    }

extension Service
    {
    @available(*, deprecated=0.99, renamed="resource(absoluteURL:)")
    @nonobjc
    public final func resource(url url: NSURL?) -> Resource
        { return resource(absoluteURL:url) }

    @available(*, deprecated=0.99, renamed="resource(absoluteURL:)")
    @nonobjc
    public final func resource(url urlString: String?) -> Resource
        { return resource(absoluteURL:urlString) }
    }

extension TypedContentAccessors
    {
    @available(*, deprecated=0.99, renamed="typedContent")
    public func contentAsType<T>(@autoclosure ifNone defaultContent: () -> T) -> T
        { return typedContent(ifNone: defaultContent) }

    @available(*, deprecated=0.99, renamed="typedContent")
    public func contentAsType<T>(@autoclosure ifNone defaultContent: () -> T?) -> T?
        { return typedContent(ifNone: defaultContent) }
    }

