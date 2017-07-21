//
//  Resource.swift
//  Siesta
//
//  Created by Paul on 2015/6/16.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//
import Foundation


// Overridable for testing
internal var fakeNow: TimeInterval?
internal let now = { fakeNow ?? Date.timeIntervalSinceReferenceDate }

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
    public let url: URL

    private let urlDescription: String
    private let permanentFailure: RequestError?

    internal var observers = [AnyHashable:ObserverEntry]()
    internal var defunctObserverCheckScheduled = false
    internal var defunctObserverCheckCounter = 0


    // MARK: Configuration

    /// Configuration when there is no request method.
    public var configuration: Configuration
        { return configuration(for: .get) }

    /// Configuration for requests with the given request method.
    public func configuration(for method: RequestMethod) -> Configuration
        {
        DispatchQueue.mainThreadPrecondition()

        if permanentFailure != nil   // Resources with invalid URLs aren’t configurable
            { return Configuration() }

        if configVersion != service.configVersion
            {
            cachedConfig.removeAll()
            configVersion = service.configVersion
            }

        return cachedConfig.cacheValue(forKey: method)
            { service.configuration(forResource: self, requestMethod: method) }
        }

    internal func configuration(for request: URLRequest) -> Configuration
        {
        return configuration(for:
            RequestMethod(rawValue: request.httpMethod?.lowercased() ?? "")
                ?? .get)  // All unrecognized methods default to .get
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
    public private(set) var latestData: Entity<Any>?
        {
        get {
            initializeDataFromCache()  // asynchronous; won't immediately change data
            return _latestData
            }

        set {
            _latestData = newValue
            invalidated = false
            }
        }

    private var _latestData: Entity<Any>?

    /**
      Details if the last attempt to load this resource resulted in an error. Becomes nil as soon
      as a request is successful.

      Note that this only reports error from `load()` and `loadIfNeeded()`, not any of the various
      flavors of `request(...)`.
    */
    public private(set) var latestError: RequestError?
        {
        didSet { invalidated = false }
        }

    /// The time of the most recent update to either `latestData` or `latestError`.
    public var timestamp: TimeInterval
        {
        DispatchQueue.mainThreadPrecondition()

        return max(
            latestData?.timestamp ?? 0,
            latestError?.timestamp ?? 0)
        }

    private var invalidated = false  // Overrides timestamp & staleness rules if true


    // MARK: Request management

    /// True if any load requests (i.e. from calls to `load(...)` and `loadIfNeeded()`)
    /// for this resource are in progress.
    public var isLoading: Bool
        {
        DispatchQueue.mainThreadPrecondition()

        return !loadRequests.isEmpty
        }

    /// True if any requests for this resource are in progress.
    public var isRequesting: Bool
        {
        DispatchQueue.mainThreadPrecondition()

        return !allRequests.isEmpty
        }

    /// All load requests in progress, in the order they were initiated.
    public private(set) var loadRequests = [Request]()

    /// All requests in progress related to this resource, in the order they were initiated.
    public private(set) var allRequests = [Request]()  // TOOD: Any special handling for concurrent POST & GET?

    // MARK: -

    internal init(service: Service, url: URL)
        {
        DispatchQueue.mainThreadPrecondition()

        self.service = service
        self.url = url.absoluteURL

        urlDescription = debugStr(url).replacingPrefix(service.baseURL?.absoluteString ?? "\0", with: "…/")
        permanentFailure = nil
        }

    internal init(service: Service, invalidURLSource: URLConvertible?)
        {
        DispatchQueue.mainThreadPrecondition()

        self.service = service
        self.url = URL(string: ":")!

        permanentFailure = RequestError(
            userMessage: NSLocalizedString("Cannot send request with invalid URL", comment: "userMessage"),
            cause: RequestError.Cause.InvalidURL(urlSource: invalidURLSource))

        if let invalidURLSource = invalidURLSource
            { urlDescription = "<invalid URL: \(invalidURLSource)>" }
        else
            { urlDescription = "<no URL>" }
        }

    // MARK: Requests

    /**
      Allows callers to arbitrarily alter the HTTP details of a request before it is sent. For example:

          resource.request(.post) {
            $0.httpBody = imageData
            $0.addValue("image/png", forHTTPHeaderField: "Content-Type")
          }

      Siesta provides helpers that make this custom `RequestMutation` unnecessary in many common cases.
      [Configuration](http://bustoutsolutions.github.io/siesta/guide/configuration/) lets you set request headers, and
      helpers such as `Resource.request(_:json:contentType:requestMutation:)` will encode common request body types for
      you. Custom mutation is the “full control” option for cases when:

      1. you need to alter the request in ways Siesta doesn’t provide helpers for, or
      2. you want to alter _one_ individual request instead of configuring _all_ requests for a resource.

      The `RequestMutation` receives a `URLRequest` _after_ Siesta has already applied all of its normal configuration.
      The `URLRequest` is mutable, and any changes it makes are the last stop before the request is sent to the network.
      What you return is what Siesta sends.

      - Note: Why is `RequestMutation` marked `@escaping` everywhere it’s used? Because `Request.repeated()` does
          not repeat the original request verbatim; instead, it recomputes the request headers using the latest
          configuration, then reapplies your `RequestMutation`.

      - SeeAlso: `Resource.request(...)`
    */
    public typealias RequestMutation = (inout URLRequest) -> ()

    /**
      Initiates a network request for the given resource.

      Handle the result of the request by attaching response handlers:

          resource.request(.get)
              .onSuccess { ... }
              .onFailure { ... }

      See `Request` for a complete list of hooks.

      Note that, unlike load() and loadIfNeeded(), this method does _not_ update latestData or latestError,
      and does not notify resource observers about the result.

      - Parameter method: The HTTP verb to use for the request
      - Parameter requestMutation:
          An optional callback to change details of the request before it is sent.
          Does nothing by default. Note that this is applied _before_ any mutations configured with
          `Configuration.mutateRequests(...)`. This allows configured mutations to inspect and alter the request after
          it is fully populated.

      - SeeAlso:
        - `load()`
        - `loadIfNeeded()`

      - SeeAlso:
        - `request(_:data:contentType:requestMutation:)`
        - `request(_:text:contentType:encoding:requestMutation:)`
        - `request(_:json:contentType:requestMutation:)`
        - `request(_:urlEncoded:requestMutation:)`
    */
    public func request(
            _ method: RequestMethod,
            requestMutation adHocMutation: @escaping RequestMutation = { _ in })
        -> Request
        {
        DispatchQueue.mainThreadPrecondition()

        if let permanentFailure = permanentFailure
            { return Resource.failedRequest(permanentFailure) }

        // Build the request

        let requestBuilder: (Void) -> URLRequest =
            {
            var underlyingRequest = URLRequest(url: self.url)
            underlyingRequest.httpMethod = method.rawValue.uppercased()
            let config = self.configuration(for: method)

            for (header, value) in config.headers
                { underlyingRequest.setValue(value, forHTTPHeaderField: header) }

            adHocMutation(&underlyingRequest)
            for configuredMutation in config.requestMutations
                { configuredMutation(&underlyingRequest) }

            debugLog(.networkDetails, ["Request:", dumpHeaders(underlyingRequest.allHTTPHeaderFields ?? [:], indent: "    ")])

            return underlyingRequest
            }

        let rawReq = NetworkRequest(resource: self, requestBuilder: requestBuilder)

        // Optionally decorate the request

        let req = rawReq.config.requestDecorators.reduce(rawReq as Request)
            { req, decorate in decorate(self, req) }

        // Track the fully decorated request

        trackRequest(req, in: &allRequests)
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

    private func logStaleness(_ result: Bool, atTime currentTime: TimeInterval)
        {
        // Logging this is far more complicated than computing it!

        func formatExpirationTime(
                _ name: String,
                _ timestamp: TimeInterval?,
                _ expirationTime: TimeInterval)
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

        debugLog(.staleness,
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
    @discardableResult
    public func loadIfNeeded() -> Request?
        {
        DispatchQueue.mainThreadPrecondition()

        if let loadReq = loadRequests.first
            {
            debugLog(.staleness, [self, "loadIfNeeded(): load is already in progress: \(loadReq)"])
            return loadReq
            }

        if isUpToDate
            { return nil }

        return load()
        }

    /**
      Initiates a GET request to update the state of this resource. This method forces a new request even if there is
      already one in progress. (See `loadIfNeeded()` for comparison.) This is the method to call if you want to force
      a check for new data — in response to a manual refresh, for example, or because you know that the data changed
      on the server.

      Sequence of events:

      1. This resource’s `isLoading` property becomes true, and remains true until the request either succeeds or fails.
         Observers immedately receive `ResourceEvent.requested`.
      2. If the request is cancelled before completion, observers receive `ResourceEvent.requestCancelled`.
      3. If the server returns a success response, that goes in `latestData`, and `latestError` becomes nil.
         Observers receive `ResourceEvent.newData`.
      3. If the server returns a 304, `latestData`’s timestamp is updated but the entity is otherwise untouched.
         `latestError` becomes nil. Observers receive `ResourceEvent.notModified`.
      4. If the request fails for any reason, whether client-, server-, or network-related, observers receive
         `ResourceEvent.error`. Note that `latestData` does _not_ become nil; the last valid response always sticks
         around until another valid response arrives.
    */
    @discardableResult
    public func load() -> Request
        {
        let req = request(.get)
            {
            underlyingRequest in
            if let etag = self.latestData?.etag
                { underlyingRequest.setValue(etag, forHTTPHeaderField: "If-None-Match") }
            }

        return load(using: req)
        }

    /**
      Updates the state of this resource using the result of the given request. Use this method when you want a request
      to update `latestData` or `latestError` and notify observers just as `load()` would, but:

      - you need to use a request method other than GET,
      - you need to set headers or other request options, but just for this one request (so that `Service.configure(...)`
        won’t work), or
      - for some arcane reason, you want a request for a _different_ resource to update the state of this one.

      For example, an authentication resource might return its state only in response to a POST:

          let auth = MyAPI.authentication
          auth.load(using:
            auth.request(
                .post, json: ["user": user, "password": pass]))
    */
    @discardableResult
    public func load(using req: Request) -> Request
        {
        DispatchQueue.mainThreadPrecondition()

        trackRequest(req, in: &loadRequests)

        req.onProgress(notifyObservers)

        req.onNewData(receiveNewDataFromNetwork)
        req.onNotModified(receiveDataNotModified)
        req.onFailure(receiveError)

        notifyObservers(.requested)

        return req
        }

    /**
      If this resource has no observers, cancels all `loadRequests`.
    */
    public func cancelLoadIfUnobserved()
        {
        DispatchQueue.mainThreadPrecondition()

        guard !beingObserved else
            { return debugLog(.networkDetails, [self, "still has", observers.count, "observer(s), so cancelLoadIfUnobserved() does nothing"]) }

        if !loadRequests.isEmpty
            { debugLog(.network, ["Canceling", loadRequests.count, "load request(s) for unobserved", self]) }

        for req in loadRequests
            { req.cancel() }
        }

    /**
      Convenience to call `cancelLoadIfUnobserved()` after a delay. Useful for situations such as table view scrolling
      where views are being rapidly discarded and recreated, and you no longer need the resource, but want to give other
      views a chance to express interest in it before canceling any requests.

      The `callback` is called aftrer the given delay, regardless of whether the request was cancelled.
    */
    public func cancelLoadIfUnobserved(afterDelay delay: TimeInterval, then callback: @escaping (Void) -> Void = {})
        {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.05)
            {
            self.cancelLoadIfUnobserved()
            callback()
            }
        }

    private func trackRequest(_ req: Request, in requests: inout [Request])
        {
        requests.append(req)
        req.onCompletion
            {
            [weak self] _ in
            self?.allRequests.remove { $0.isCompleted }
            self?.loadRequests.remove { $0.isCompleted }
            }
        }

    private func receiveNewDataFromNetwork(_ entity: Entity<Any>)
        { receiveNewData(entity, source: .network) }

    private func receiveNewData(_ entity: Entity<Any>, source: ResourceEvent.NewDataSource)
        {
        DispatchQueue.mainThreadPrecondition()

        debugLog(.stateChanges, [self, "received new data from", source, ":", entity])

        latestError = nil
        latestData = entity

        // A local override means our cached data may be defunct.
        // (Other sources don't affect the cache: pipeline will have already cached a network success;
        // we don't write back data just read from cache; wiping doesn't wipe the cache.)

        if case .localOverride = source
            { configuration.pipeline.removeCacheEntries(for: self) }

        notifyObservers(.newData(source))
        }

    private func receiveDataNotModified()
        {
        debugLog(.stateChanges, [self, "existing data is still valid"])

        latestError = nil
        latestData?.touch()
        if let timestamp = latestData?.timestamp
            { configuration.pipeline.updateCacheEntryTimestamps(timestamp, for: self) }

        notifyObservers(.notModified)
        }

    private func receiveError(_ error: RequestError)
        {
        if error.cause is RequestError.Cause.RequestCancelled
            {
            notifyObservers(.requestCancelled)
            return
            }

        debugLog(.stateChanges, [self, "received error:", error])

        latestError = error

        notifyObservers(.error)
        }

    // MARK: Local state changes

    /**
      Directly updates `latestData` without touching the network. Clears `latestError` and broadcasts
      `ResourceEvent.newData` to observers.

      This method is useful for incremental and optimistic updates.

      You may send a request which does _not_ return the complete state of the resource in the response body,
      but which still changes the state of the resource. You could handle this by initiating a refresh immedately
      after success:

          resource.request(.post, json: ["name": "Fred"])
            .onSuccess { _ in resource.load() }

      However, if you already _know_ the resulting state of the resource given a success response, you can avoid the
      second network call by updating the entity yourself:

          resource.request(.post, json: ["name": "Fred"])
            .onSuccess {
                partialEntity in

                // Make a mutable copy of the current content
                guard resource.latestData != nil else {
                    resource.load()  // No existing entity to update, so refresh
                    return
                }

                // Do the incremental update
                var updatedContent = resource.jsonDict
                updatedContent["name"] = partialEntity.jsonDict["newName"]

                // Make that the resource’s new entity
                resource.overrideLocalContent(with: updatedContent)
            }

      Use this technique with caution!

      Note that the data you pass does _not_ go through the standard `ResponseTransformer` chain. You should pass data
      as if it was already parsed, not in its raw form as the server would return it. For example, in the code above,
      `updatedContent` is a `Dictionary`, not `Data` containing encoded JSON.

      - SeeAlso: `overrideLocalContent(with:)`
    */
    public func overrideLocalData(with entity: Entity<Any>)
        { receiveNewData(entity, source: .localOverride) }

    /**
      Convenience method to replace the `content` of `latestData` without altering the content type or other headers.

      If this resource has no content, this method sets the content type to `application/binary`.
    */
    public func overrideLocalContent(with content: Any)
        {
        var updatedEntity = latestData ?? Entity<Any>(content: content, contentType: "application/binary")
        updatedEntity.content = content
        updatedEntity.touch()
        overrideLocalData(with: updatedEntity)
        }

    /**
      Forces the next call to `loadIfNeeded()` to trigger a request, even if the current content is fresh.
      Leaves the current values of `latestData` and `latestError` intact (including their timestamps).

      Use this if you know the current content is stale, but don’t want to trigger a network request right away.

      Any update to `latestData` or `latestError` — including a call to `overrideLocalData(...)` or
      `overrideLocalContent(...)` — clears the invalidation.

      - SeeAlso: `wipe()`
    */
    public func invalidate()
        {
        DispatchQueue.mainThreadPrecondition()

        invalidated = true
        }

    /**
      Resets this resource to its pristine state, as if newly created.

      - Sets `latestData` to nil.
      - Sets `latestError` to nil.
      - Cancels all resource requests in progress.

      Observers receive a `newData` event. Requests in progress call completion hooks with a cancellation error.

      - SeeAlso: `invalidate()`
    */
    public func wipe()
        {
        DispatchQueue.mainThreadPrecondition()

        debugLog(.stateChanges, [self, "wiped"])

        for request in allRequests + loadRequests  // need to do both because load(using:) can cross resource boundaries
            { request.cancel() }

        latestError = nil
        latestData = nil

        notifyObservers(.newData(.wipe))

        loadDataFromCache()
        }

    // MARK: Caching

    internal func observersChanged()
        {
        initializeDataFromCache()
        // Future config callbacks for observed/unobserved may go here
        }

    private var initialCacheCheckDone = false  // We wait to check for cached data until first observer added

    private func initializeDataFromCache()
        {
        if !initialCacheCheckDone
            {
            initialCacheCheckDone = true
            loadDataFromCache()
            }
        }

    private func loadDataFromCache()
        {
        configuration.pipeline.cachedEntity(for: self)
            {
            [weak self] entity in
            guard let resource = self, resource.latestData == nil else
                {
                debugLog(.cache, ["Ignoring cache hit for", self, " because it is either deallocated or already has data"])
                return
                }

            resource.receiveNewData(entity, source: .cache)
            }
        }

    // MARK: Debug

    /// :nodoc:
    public override var description: String
        {
        return "Resource("
            + urlDescription
            + ")["
            + (isLoading ? "L" : "")
            + (_latestData != nil ? "D" : "")
            + (latestError != nil ? "E" : "")
            + "]"
        }
    }
