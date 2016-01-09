//
//  Deprecations.swift
//  Siesta
//
//  Created by Paul on 2015/12/12.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

extension Entity
    {
    @available(*, deprecated=1.0, renamed="Entity(response:content:)")
    public init(_ response: NSHTTPURLResponse?, _ content: Any)
        { self.init(response: response, content: content) }
    }

extension Error
    {
    @available(*, deprecated=1.0, renamed="Error(response:content:cause:userMessage:)")
    public init(
            _ response: NSHTTPURLResponse?,
            _ content: AnyObject?,
            _ cause: ErrorType?,
            userMessage: String? = nil)
        { self.init(response: response, content: content, cause: cause, userMessage: userMessage) }
    }

extension Resource
    {
    @available(*, deprecated=1.0, renamed="isLoading")
    public var loading: Bool
        { return isLoading }

    @available(*, deprecated=1.0, renamed="isRequesting")
    public var requesting: Bool
        { return isRequesting }

    @available(*, deprecated=1.0, renamed="overrideLocalData")
    public func localDataOverride(entity: Entity)
        { overrideLocalData(entity) }

    @available(*, deprecated=1.0, renamed="overrideLocalContent")
    public func localContentOverride(content: AnyObject)
        { overrideLocalContent(content) }
    }

extension Request
    {
    @available(*, deprecated=1.0, renamed="isCompleted")
    public var completed: Bool
        { return isCompleted }

    @available(*, deprecated=1.0, renamed="onCompletion")
    func completion(callback: Response -> Void) -> Self
        { return onCompletion(callback) }

    @available(*, deprecated=1.0, renamed="onSuccess")
    func success(callback: Entity -> Void) -> Self
        { return onSuccess(callback) }

    @available(*, deprecated=1.0, renamed="onNewData")
    func newData(callback: Entity -> Void) -> Self
        { return onNewData(callback) }

    @available(*, deprecated=1.0, renamed="onNotModified")
    func notModified(callback: Void -> Void) -> Self
        { return onNotModified(callback) }

    @available(*, deprecated=1.0, renamed="onFailure")
    func failure(callback: Error -> Void) -> Self
        { return onFailure(callback) }

    @available(*, deprecated=1.0, renamed="onProgress")
    func progress(callback: Double -> Void) -> Self
        { return onProgress(callback) }

    }

extension Service
    {
    @available(*, deprecated=1.0, renamed="resourceWithURL")
    public final func resource(url url: NSURL?) -> Resource
        { return resourceWithURL(url) }

    @available(*, deprecated=1.0, renamed="resourceWithURL")
    @objc(_deprecatedResourceWithURL:)
    public final func resource(url urlString: String?) -> Resource
        { return resourceWithURL(urlString) }
    }
