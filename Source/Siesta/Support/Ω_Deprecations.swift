//
//  ΩDeprecations.swift  ← Ω prefix forces CocoaPods to build this last, which matters for nested type extensions
//  Siesta
//
//  Created by Paul on 2015/12/12.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//


import Foundation

// MARK: Deprecated in 1.0-rc.1

extension LogCategory
    {
    @available(*, deprecated: 0.99, renamed: "pipeline")
    public static let responseProcessing = LogCategory.pipeline
    }

@available(*, deprecated: 0.99, renamed: "LogCategory.enabled")
public var enabledLogCategories: Set<LogCategory>
    {
    get { return LogCategory.enabled }
    set { LogCategory.enabled = newValue }
    }

extension ResourceObserver
    {
    @available(*, unavailable, message: "superseded by observerIdentity")
    public func isEquivalentTo(observer: ResourceObserver) -> Bool
        { fatalError("no longer available") }

    @available(*, unavailable, message: "superseded by observerIdentity")
    public func isEquivalentToObserver(_ other: ResourceObserver) -> Bool
        { fatalError("no longer available") }
    }

// MARK: Swift 3 deprecations

extension Configuration
    {
    @available(*, unavailable, message: "Globally replace `$0.config` with `$0`")
    public var config: Configuration
        {
        get { fatalError("no longer available") }
        set { fatalError("no longer available") }
        }
    }

extension Resource
    {
    @available(*, deprecated: 0.99, renamed: "configuration(for:)")
    public func configuration(forRequestMethod method: Siesta.RequestMethod) -> Siesta.Configuration
        { return configuration(for: method) }


    @available(*, deprecated: 0.99, renamed: "load(using:)")
    public func load(usingRequest req: Request) -> Request
        { return load(using: req) }

    @available(*, deprecated: 0.99, renamed: "overrideLocalData(with:)")
    public func overrideLocalData(_ entity: Siesta.Entity<Any>)
        { return overrideLocalData(with: entity) }

    @available(*, deprecated: 0.99, renamed: "overrideLocalContent(with:)")
    public func overrideLocalContent(_ content: AnyObject)
        { return overrideLocalContent(with: content) }
    }

extension Service
    {
    @available(*, deprecated: 0.99, renamed: "wipeResources(withURLsMatching:)")
    final public func wipeResourcesMatchingURL(predicate: (URL) -> Bool)
        { return wipeResources(withURLsMatching: predicate) }
    }

extension NSRegularExpression
    {
    @available(*, deprecated: 0.99, renamed: "configurationPattern(for:)")
    public func configurationPattern(_ service: Siesta.Service) -> (URL) -> Bool
        { return configurationPattern(for: service) }
    }

extension Resource
    {
    @available(*, deprecated: 0.99, renamed: "configurationPattern(for:)")
    public func configurationPattern(_ service: Siesta.Service) -> (URL) -> Bool
        { return configurationPattern(for: service) }
    }

extension String
    {
    @available(*, deprecated: 0.99, renamed: "configurationPattern(for:)")
    public func configurationPattern(_ service: Siesta.Service) -> (URL) -> Bool
        { return configurationPattern(for: service) }
    }

extension InputTypeMismatchAction
    {
    @available(*, deprecated: 0.99, renamed: "error")
    public static let Error = InputTypeMismatchAction.error

    @available(*, deprecated: 0.99, renamed: "skip")
    public static let Skip = InputTypeMismatchAction.skip

    @available(*, deprecated: 0.99, renamed: "skipIfOutputTypeMatches")
    public static let SkipIfOutputTypeMatches = InputTypeMismatchAction.skipIfOutputTypeMatches
    }

extension LogCategory
    {
    @available(*, deprecated: 0.99, renamed: "network")
    public static let Network = LogCategory.network

    @available(*, deprecated: 0.99, renamed: "networkDetails")
    public static let NetworkDetails = LogCategory.networkDetails

    @available(*, deprecated: 0.99, renamed: "pipeline")
    public static let ResponseProcessing = LogCategory.pipeline

    @available(*, deprecated: 0.99, renamed: "stateChanges")
    public static let StateChanges = LogCategory.stateChanges

    @available(*, deprecated: 0.99, renamed: "observers")
    public static let Observers = LogCategory.observers

    @available(*, deprecated: 0.99, renamed: "staleness")
    public static let Staleness = LogCategory.staleness

    @available(*, deprecated: 0.99, renamed: "cache")
    public static let Cache = LogCategory.cache

    @available(*, deprecated: 0.99, renamed: "configuration")
    public static let Configuration = LogCategory.configuration
    }

extension RequestChainAction
    {
    @available(*, deprecated: 0.99, renamed: "passTo")
    public static let PassTo = RequestChainAction.passTo

    @available(*, deprecated: 0.99, renamed: "useResponse")
    public static let UseResponse = RequestChainAction.useResponse

    @available(*, deprecated: 0.99, renamed: "useThisResponse")
    public static let UseThisResponse = RequestChainAction.useThisResponse
    }

extension RequestMethod
    {
    @available(*, deprecated: 0.99, renamed: "get")
    public static let GET = RequestMethod.get

    @available(*, deprecated: 0.99, renamed: "post")
    public static let POST = RequestMethod.post

    @available(*, deprecated: 0.99, renamed: "put")
    public static let PUT = RequestMethod.put

    @available(*, deprecated: 0.99, renamed: "patch")
    public static let PATCH = RequestMethod.patch

    @available(*, deprecated: 0.99, renamed: "delete")
    public static let DELETE = RequestMethod.delete
    }

extension ResourceEvent
    {
    @available(*, deprecated: 0.99, renamed: "observerAdded")
    public static let ObserverAdded = ResourceEvent.observerAdded

    @available(*, deprecated: 0.99, renamed: "requested")
    public static let Requested = ResourceEvent.requested

    @available(*, deprecated: 0.99, renamed: "requestCancelled")
    public static let RequestCancelled = ResourceEvent.requestCancelled

    @available(*, deprecated: 0.99, renamed: "newData")
    public static let NewData = ResourceEvent.newData

    @available(*, deprecated: 0.99, renamed: "notModified")
    public static let NotModified = ResourceEvent.notModified

    @available(*, deprecated: 0.99, renamed: "error")
    public static let Error = ResourceEvent.error
    }

extension ResourceEvent.NewDataSource
    {
    @available(*, deprecated: 0.99, renamed: "network")
    public static let Network = ResourceEvent.NewDataSource.network

    @available(*, deprecated: 0.99, renamed: "cache")
    public static let Cache = ResourceEvent.NewDataSource.cache

    @available(*, deprecated: 0.99, renamed: "localOverride")
    public static let LocalOverride = ResourceEvent.NewDataSource.localOverride

    @available(*, deprecated: 0.99, renamed: "wipe")
    public static let Wipe = ResourceEvent.NewDataSource.wipe
    }

extension Response
    {
    @available(*, deprecated: 0.99, renamed: "success")
    public static let Success = Response.success

    @available(*, deprecated: 0.99, renamed: "failure")
    public static let Failure = Response.failure
    }

extension ConfigurationPatternConvertible
    {
    @available(*, deprecated: 0.99, renamed: "configurationPattern(for:)")
    public func configurationPattern(_ service: Siesta.Service) -> (URL) -> Bool
        { return configurationPattern(for: service) }
    }

extension Entity
    {
    @available(*, deprecated: 0.99, renamed: "header(forKey:)")
    public func header(_ key: String) -> String?
        { return header(forKey: key) }
    }
