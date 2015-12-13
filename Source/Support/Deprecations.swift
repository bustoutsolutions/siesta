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
    }

extension Service
    {
    @available(*, deprecated=1.0, renamed="base")
    public var baseURL: NSURL?
        { return base }

    @available(*, deprecated=1.0, renamed="resourceWithURL")
    public final func resource(url url: NSURL?) -> Resource
        { return resourceWithURL(url) }

    @available(*, deprecated=1.0, renamed="resourceWithURL")
    @objc(_deprecatedResourceWithURL:)
    public final func resource(url urlString: String?) -> Resource
        { return resourceWithURL(urlString) }
    }
