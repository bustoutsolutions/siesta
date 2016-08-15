//
//  Resource.swift
//  Siesta
//
//  Created by Paul on 2015/6/16.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//
import Foundation


// Overridable for testing
internal var fakeNow: NSTimeInterval?
internal let now = { fakeNow ?? NSDate.timeIntervalSinceReferenceDate() }

/**
  An in-memory cache of a RESTful resource, plus information about the status of network requests related to it.

  This class answers three basic questions about a resource:

  * What is the latest data for the resource this device has retrieved, if any?
  * Did the last attempt to load it result in an error?
  * Is there a request in progress?

  …and allows multiple observer to register to be notified whenever the answers to any of these
  questions changes.
*/
@objc(BOSResource)
public final class Resource: NSObject
    {
    // MARK: Essentials

    /// The API to which this resource belongs. Provides configuration defaults and instance uniqueness.
    public let service: Service

    /// The canoncial URL of this resource.
    public let url: NSURL

    internal var observers = [ObserverEntry]()

    /// Configuration when there is no request method.
    public var configuration: Configuration
        { return configuration(forRequestMethod: .GET) }

    /// Configuration for requests with the given request method.
    public func configuration(forRequestMethod method: RequestMethod) -> Configuration
        {
        dispatch_assert_main_queue()

        if configVersion != service.configVersion
            {
            cachedConfig.removeAll()
            configVersion = service.configVersion
            }

        return cachedConfig.cacheValue(forKey: method)
            { service.configuration(forResource: self, requestMethod: method) }
        }

    internal func configuration(forRequest request: NSURLRequest) -> Configuration
        {
        return configuration(forRequestMethod:
            RequestMethod(rawValue: request.HTTPMethod?.uppercaseString ?? "")
                ?? .GET)  // All unrecognized methods default to .GET
        }

    private var cachedConfig: [RequestMethod:Configuration] = [:]
    private var configVersion: UInt64 = 0


    // MARK: Resource state

    /**
       The latest valid data we have for this resource. May come from a server response, a cache,
       or a local override.

       Note that this property represents the __full state__ of the resource. It therefore only holds entities fetched
       with `load()` and `loadIfNeeded()`, not any of the various flavors of `request(...)`.

       Note that `latestData` will be present as long as there has _ever_ been a succesful request since the resource
       was created or wiped. If an error occurs, `latestData` will still hold the latest (now stale) valid data.

       - SeeAlso: `TypedContentAccessors`
    */
    public private(set) var latestData: Entity?
        {
        didSet { invalidated = false }
        }

    /**
      Details if the last attempt to load this resource resulted in an error. Becomes nil as soon
      as a request is successful.

      Note that this only reports error from `load()` and `loadIfNeeded()`, not any of the various
      flavors of `request(...)`.
    */
    public private(set) var latestError: Error?
        {
        didSet { invalidated = false }
        }

    /// The time of the most recent update to either `latestData` or `latestError`.
    public var timestamp: NSTimeInterval
        {
        dispatch_assert_main_queue()

        return max(
            latestData?.timestamp ?? 0,
            latestError?.timestamp ?? 0)
        }

    private var invalidated = false


    // MARK: Request management

    /// True if any load requests (i.e. from calls to `load(...)` and `loadIfNeeded()`)
    /// for this resource are in progress.
    public var isLoading: Bool
        {
        dispatch_assert_main_queue()

        return !loadRequests.isEmpty
        }

    /// True if any requests for this resource are in progress.
    public var isRequesting: Bool
        {
        dispatch_assert_main_queue()

        return !allRequests.isEmpty
        }

    /// All load requests in progress, in the order they were initiated.
    public private(set) var loadRequests = [Request]()

    /// All requests in progress related to this resource, in the order they were initiated.
    public private(set) var allRequests = [Request]()  // TOOD: Any special handling for concurrent POST & GET?

    // MARK: -

    internal init(service: Service, url: NSURL)
        {
        dispatch_assert_main_queue()

        self.service = service
        self.url = url.absoluteURL

        super.init()

        initializeDataFromCache()
        }

    // MARK: URL navigation

    /**
      Returns the resource with the given string appended to the path of this resource’s URL, with a joining slash
      inserted if necessary.

      Use this method for hierarchical resource navigation. The typical use case is constructing a resource URL from
      path components and IDs:

          let resource = service.resource("/widgets")
          resource.child("123").child("details")
            //→ /widgets/123/details

      This method _always_ returns a subpath of the receiving resource. It does not apply any special
      interpretation to strings such `./`, `//` or `?` that have significance in other URL-related
      situations. Special characters are escaped when necessary, and otherwise ignored. See
      [`ResourcePathsSpec`](https://bustoutsolutions.github.io/siesta/specs/#ResourcePathsSpec)
      for details.

      - SeeAlso: `relative(_:)`
    */
    @warn_unused_result
    public func child(subpath: String) -> Resource
        {
        return service.resource(absoluteURL: url.URLByAppendingPathComponent(subpath))
        }

    /**
      Returns the resource with the given URL, using this resource’s URL as the base if it is a relative URL.

      This method interprets strings such as `.`, `..`, and a leading `/` or `//` as relative URLs. It resolves its
      parameter much like an `href` attribute in an HTML document. Refer to
      [`ResourcePathsSpec`](https://bustoutsolutions.github.io/siesta/specs/#ResourcePathsSpec)
      for details.

      - SeeAlso:
        - `optionalRelative(_:)`
        - `child(_:)`
    */
    @warn_unused_result
    public func relative(href: String) -> Resource
        {
        return service.resource(absoluteURL: NSURL(string: href, relativeToURL: url))
        }

    /**
      Returns `relative(href)` if `href` is present, and nil if `href` is nil.

      This convenience method is useful for resolving URLs returned as part of a JSON response body:

          let href = resource.jsonDict["owner"] as? String  // href is an optional
          if let ownerResource = resource.optionalRelative(href) {
            // ...
          }
    */
    @warn_unused_result
    public func optionalRelative(href: String?) -> Resource?
        {
        if let href = href
            { return relative(href) }
        else
            { return nil }
        }

    /**
      Returns this resource with the given parameter added or changed in the query string.

      If `value` is an empty string, the parameter goes in the query string with no value (e.g. `?foo`).
      If `value` is nil, the parameter is removed.

      There is no support for parameters with an equal sign but an empty value (e.g. `?foo=`).
      There is also no support for repeated keys in the query string (e.g. `?foo=1&foo=2`).
      If you need to circumvent either of these restrictions, you can create the query string yourself and pass
      it to `relative(_:)` instead of using `withParam(_:_:)`.

      Note that `Service` gives out unique `Resource` instances according to the full URL in string form, and thus
      considers query string parameter order significant. Therefore, to ensure that you get the same `Resource`
      instance no matter the order in which you specify parameters, `withParam(_:_:)` sorts all parameters by name.
      Note that _only_ `withParam(_:_:)` does this sorting; if you use other methods to create query strings, it is
      up to you to canonicalize your parameter order.
    */
    @warn_unused_result
    @objc(withParam:value:)
    public func withParam(name: String, _ value: String?) -> Resource
        {
        return service.resource(absoluteURL:
            url.alterQuery
                {
                var params = $0
                params[name] = value
                return params
                })
        }

    // MARK: Requests

    /**
      Initiates a network request for the given resource.

      Handle the result of the request by attaching response handlers:

          resource.request(.GET)
              .success { ... }
              .failure { ... }

      See `Request` for a complete list of hooks.

      Note that, unlike load() and loadIfNeeded(), this method does _not_ update latestData or latestError,
      and does not notify resource observers about the result.

      - Parameter method: The HTTP verb to use for the request
      - Parameter requestMutation:
          An optional callback to change details of the request before it is sent. For example:

              request(.POST) { nsreq in
                nsreq.HTTPBody = imageData
                nsreq.addValue(
                  "image/png",
                  forHTTPHeaderField:
                    "Content-Type")
              }

          Does nothing by default.

      - SeeAlso:
        - `load()`
        - `loadIfNeeded()`

      - SeeAlso:
        - `request(_:data:contentType:requestMutation:)`
        - `request(_:text:contentType:encoding:requestMutation:)`
        - `request(_:json:contentType:requestMutation:)`
        - `request(_:urlEncoded:requestMutation:)`
    */
    @warn_unused_result
    public func request(
            method: RequestMethod,
            @noescape requestMutation: NSMutableURLRequest -> () = { _ in })
        -> Request
        {
        dispatch_assert_main_queue()

        let nsreq = NSMutableURLRequest(URL: url)
        nsreq.HTTPMethod = method.rawValue
        for (header,value) in configuration(forRequestMethod: method).headers
            { nsreq.setValue(value, forHTTPHeaderField: header) }

        requestMutation(nsreq)

        debugLog(.NetworkDetails, ["Request:", dumpHeaders(nsreq.allHTTPHeaderFields ?? [:], indent: "    ")])

        let req = NetworkRequest(resource: self, nsreq: nsreq)
        trackRequest(req, using: &allRequests)
        for callback in req.config.beforeStartingRequestCallbacks
            { callback(self, req) }

        return req.start()
        }

    /**
      True if the resource’s local state is up to date according to staleness configuration.

      “Up to date” means that either:

        - the resource has data (i.e. `latestData` is not nil),
        - the last request succeeded (i.e. `latestError` _is_ nil), and
        - the timestamp on `latestData` is more recent than `expirationTime` seconds ago,

      …or:

        - the last request failed (i.e. `latestError` is not nil), and
        - the timestamp on `latestError` is more recent than `retryTime` seconds ago.
    */
    public var isUpToDate: Bool
        {
        let maxAge = (latestError == nil)
                ? configuration.expirationTime
                : configuration.retryTime,
            currentTime = now(),
            result = !invalidated && currentTime - timestamp <= maxAge

        logStaleness(result, atTime: currentTime)

        return result
        }

    private func logStaleness(result: Bool, atTime currentTime: NSTimeInterval)
        {
        // Logging this is far more complicated than computing it!

        func formatExpirationTime(
                name: String,
                _ timestamp: NSTimeInterval?,
                _ expirationTime: NSTimeInterval)
            -> [Any?]
            {
            guard let timestamp = timestamp else
                { return ["no", name] }

            let delta = timestamp + expirationTime - currentTime,
                deltaFormatted = String(format: "%1.1lf", fabs(delta))
            return delta >= 0
                ? [name, "is valid for another", deltaFormatted, "sec"]
                : [name, "expired", deltaFormatted, "sec ago"]
            }

        debugLog(.Staleness,
            [self, (result ? "is" : "is not"), "up to date:"]
            + formatExpirationTime("error", latestError?.timestamp, configuration.retryTime)
            + ["|"]
            + formatExpirationTime("data",  latestData?.timestamp,  configuration.expirationTime))
        }

    /**
      Ensures that there is a load request in progress for this resource, unless the resource is already up to date.

      If the resource is not up to date and there is no load request already in progress, this method calls `load()`.

      - SeeAlso:
        - `isUpToDate`
        - `load()`
    */
    public func loadIfNeeded() -> Request?
        {
        dispatch_assert_main_queue()

        if let loadReq = loadRequests.first
            {
            debugLog(.Staleness, [self, "loadIfNeeded(): load is already in progress: \(loadReq)"])
            return loadReq
            }

        if isUpToDate
            { return nil }

        return load()
        }

    /**
      Initiates a GET request to update the state of this resource.

      Sequence of events:

      1. This resource’s `isLoading` property becomes true, and remains true until the request either succeeds or fails.
         Observers immedately receive `ResourceEvent.Requested`.
      2. If the request is cancelled before completion, observers receive `ResourceEvent.RequestCancelled`.
      3. If the server returns a success response, that goes in `latestData`, and `latestError` becomes nil.
         Observers receive `ResourceEvent.NewData`.
      3. If the server returns a 304, `latestData`’s timestamp is updated but the entity is otherwise untouched.
         `latestError` becomes nil. Observers receive `ResourceEvent.NotModified`.
      4. If the request fails for any reason, whether client-, server-, or network-related, observers receive
         `ResourceEvent.Error`. Note that `latestData` does _not_ become nil; the last valid response always sticks
         around until another valid response arrives.
    */
    public func load() -> Request
        {
        let req = request(.GET)
            {
            nsreq in
            if let etag = latestData?.etag
                { nsreq.setValue(etag, forHTTPHeaderField: "If-None-Match") }
            }

        return load(usingRequest: req)
        }

    /**
      Updates the state of this resource using the result of the given request. Use this method when you want a request
      to update `latestData` or `latestError` and notify observers just as `load()` would, but:

      - you need to use a request method other than GET,
      - you need to set headers or other request options, but just for this one request (so that `Service.configure`
        won’t work), or
      - for some arcane reason, you want a request for a _different_ resource to update the state of this one.

      For example, an authentication resource might return its state only in response to a POST:

          let auth = MyAPI.authentication
          auth.load(usingRequest:
            auth.request(
                .POST, json: ["user": user, "password": pass]))
    */
    public func load(usingRequest req: Request) -> Request
        {
        dispatch_assert_main_queue()

        trackRequest(req, using: &loadRequests)

        req.onProgress(notifyObservers)

        req.onNewData(receiveNewDataFromNetwork)
        req.onNotModified(receiveDataNotModified)
        req.onFailure(receiveError)

        notifyObservers(.Requested)

        return req
        }

    /**
      If this resource has no observers, cancels all `loadRequests`.
    */
    public func cancelLoadIfUnobserved()
        {
        dispatch_assert_main_queue()

        if beingObserved
            { debugLog(.NetworkDetails, [self, "still has", observers.count, "observer(s), so cancelLoadIfUnobserved() does nothing"]) }
        else
            {
            if !loadRequests.isEmpty
                { debugLog(.Network, ["Canceling", loadRequests.count, "load request(s) for unobserved", self]) }

            for req in loadRequests
                { req.cancel() }
            }
        }

    /**
      Convenience to call `cancelLoadIfUnobserved()` after a delay. Useful for situations such as table view scrolling
      where views are being rapidly discarded and recreated, and you no longer need the resource, but want to give other
      views a chance to express interest in it before canceling any requests.
    */
    public func cancelLoadIfUnobserved(afterDelay delay: NSTimeInterval, callback: Void -> Void = {})
        {
        dispatch_on_main_queue(after: 0.05)
            {
            self.cancelLoadIfUnobserved()
            callback()
            }
        }

    private func trackRequest(req: Request, inout using array: [Request])
        {
        array.append(req)
        req.onCompletion
            {
            [weak self] _ in
            self?.allRequests.remove { $0.isCompleted }
            self?.loadRequests.remove { $0.isCompleted }
            }
        }

    private func receiveNewDataFromNetwork(entity: Entity)
        { receiveNewData(entity, source: .Network) }

    private func receiveNewData(entity: Entity, source: ResourceEvent.NewDataSource)
        {
        dispatch_assert_main_queue()

        debugLog(.StateChanges, [self, "received new data from", source, ":", entity])

        latestError = nil
        latestData = entity

        // A local override means our cached data may be defunct.
        // (Other sources don't affect the cache: pipeline will have already cached a network success;
        // we don't write back data just read from cache; wiping doesn't wipe the cache.)

        if case .LocalOverride = source
            { configuration.pipeline.removeCacheEntries(for: self) }

        notifyObservers(.NewData(source))
        }

    private func receiveDataNotModified()
        {
        debugLog(.StateChanges, [self, "existing data is still valid"])

        latestError = nil
        latestData?.touch()
        if let timestamp = latestData?.timestamp
            { configuration.pipeline.updateCacheEntryTimestamps(timestamp, for: self) }

        notifyObservers(.NotModified)
        }

    private func receiveError(error: Error)
        {
        if error.cause is Error.Cause.RequestCancelled
            {
            notifyObservers(.RequestCancelled)
            return
            }

        debugLog(.StateChanges, [self, "received error:", error])

        latestError = error

        notifyObservers(.Error)
        }

    // MARK: Local state changes

    /**
      Directly updates `latestData` without touching the network. Clears `latestError` and broadcasts
      `ResourceEvent.NewData` to observers.

      This method is useful for incremental and optimistic updates.

      You may send a request which does _not_ return the complete state of the resource in the response body,
      but which still changes the state of the resource. You could handle this by initiating a refresh immedately
      after success:

          resource.request(method: .POST, json: ["name": "Fred"])
            .success { _ in resource.load() }

      However, if you already _know_ the resulting state of the resource given a success response, you can avoid the
      second network call by updating the entity yourself:

          resource.request(method: .POST, json: ["name": "Fred"])
            .success { partialEntity in

                // Make a mutable copy of the current content
                var updatedContent = resource.jsonDict

                // Do the incremental update
                updatedContent["name"] = parialEntity["newName"]

                // Make that the resource’s new entity
                resource.overrideLocalContent(updatedEntity)
            }

      Use this technique with caution!

      Note that the data you pass does _not_ go through the standard `ResponseTransformer` chain. You should pass data
      as if it was already parsed, not in its raw form as the server would return it. For example, in the code above,
      `updatedContent` is a `Dictionary`, not `NSData` containing encoded JSON.

      - SeeAlso: `overrideLocalContent(_:)`
    */
    public func overrideLocalData(entity: Entity)
        { receiveNewData(entity, source: .LocalOverride) }

    /**
      Convenience method to replace the `content` of `latestData` without altering the content type or other headers.

      If this resource has no content, this method sets the content type to `application/binary`.
    */
    public func overrideLocalContent(content: AnyObject)
        {
        var updatedEntity = latestData ?? Entity(content: content, contentType: "application/binary")
        updatedEntity.content = content
        updatedEntity.touch()
        overrideLocalData(updatedEntity)
        }

    /**
      Forces the next call to `loadIfNeeded()` to trigger a request, even if the current content is fresh.
      Leaves the current values of `latestData` and `latestError` intact (including their timestamps).

      Use this if you know the current content is stale, but don’t want to trigger a network request right away.

      Any update to `latestData` or `latestError` — including a call to `overrideLocalData()` or
      `overrideLocalContent()` — clears the invalidation.

      - SeeAlso: `wipe()`
    */
    public func invalidate()
        {
        dispatch_assert_main_queue()

        invalidated = true
        }

    /**
      Resets this resource to its pristine state, as if newly created.

      - Sets `latestData` to nil.
      - Sets `latestError` to nil.
      - Cancels all resource requests in progress.

      Observers receive a `NewData` event. Requests in progress call completion hooks with a cancellation error.

      - SeeAlso: `invalidate()`
    */
    public func wipe()
        {
        dispatch_assert_main_queue()

        debugLog(.StateChanges, [self, "wiped"])

        for request in allRequests + loadRequests  // need to do both because load(usingRequest:) can cross resource boundaries
            { request.cancel() }

        latestError = nil
        latestData = nil

        notifyObservers(.NewData(.Wipe))

        initializeDataFromCache()
        }

    // MARK: Caching

    private func initializeDataFromCache()
        {
        configuration.pipeline.cachedEntity(for: self)
            {
            [weak self] entity in
            guard let resource = self where resource.latestData == nil else
                {
                debugLog(.Cache, ["Ignoring cache hit for", self, " because it is either deallocated or already has data"])
                return
                }

            resource.receiveNewData(entity, source: .Cache)
            }
        }

    // MARK: Debug

    /// :nodoc:
    public override var description: String
        {
        return "Siesta.Resource("
            + debugStr(url)
            + ")["
            + (isLoading ? "L" : "")
            + (latestData != nil ? "D" : "")
            + (latestError != nil ? "E" : "")
            + "]"
        }
    }

extension Resource: WeakCacheValue
    {
    func allowRemovalFromCache()
        { cleanDefunctObservers() }
    }

/// Dictionaries and arrays can both be passed to `Resource.request(_:json:contentType:requestMutation:)`.
public protocol NSJSONConvertible: AnyObject { }
extension NSDictionary: NSJSONConvertible { }
extension NSArray:      NSJSONConvertible { }
