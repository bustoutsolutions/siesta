//
//  Ω_Deprecations.swift  ← Ω prefix forces CocoaPods to build this last, which matters for nested type extensions
//  Siesta
//
//  Created by Paul on 2015/12/12.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

// swiftlint:disable missing_docs

import Foundation

extension Service
    {
    @available(*, deprecated: 1.3, message: "Use `standardTransformers:` instead of `useDefaultTransformers:`. Choices are `[.json, .text, .image]`; use [] for none")
    public convenience init(
            baseURL: URLConvertible? = nil,
            useDefaultTransformers: Bool,
            networking: NetworkingProviderConvertible = URLSessionConfiguration.ephemeral)
        {
        if useDefaultTransformers
            { self.init(baseURL: baseURL, networking: networking) }
        else
            { self.init(baseURL: baseURL, standardTransformers: [], networking: networking) }
        }
    }

extension Request
    {
    @available(*, deprecated: 1.4, message: "Replaced by `state` property; check `request.state == .completed`")
    var isCompleted: Bool
        { return state == .completed }
    }

@available(*, deprecated: 1.4, renamed: "ResponseContentTransformer.InputTypeMismatchAction")
public typealias InputTypeMismatchAction = ResponseContentTransformer<Any,Any>.InputTypeMismatchAction


@available(*, deprecated: 1.4, renamed: "failedRequest(returning:)")
extension Resource
    {
    public static func failedRequest(_ error: RequestError) -> Request
        { return failedRequest(returning: error) }
    }

@available(*, deprecated: 1.4, renamed: "SiestaLog.Category")
public typealias LogCategory = SiestaLog.Category

@available(*, deprecated: 1.4, renamed: "SiestaLog.messageHandler")
public var logger: (LogCategory, String) -> Void
    {
    get { return SiestaLog.messageHandler }
    set { SiestaLog.messageHandler = newValue }
    }
