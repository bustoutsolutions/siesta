//
//  Resource.swift
//  Siesta
//
//  Created by Paul on 2015/6/16.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//


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
public final class Resource: NSObject, CustomDebugStringConvertible
    {
    // MARK: Configuration
    
    /// The API to which this resource belongs. Provides configuration defaults and instance uniqueness.
    public let service: Service
    
    /// The canoncial URL of this resource.
    public let url: NSURL? // TODO: figure out what to do about invalid URLs
    
    internal var observers = [ObserverEntry]()
    
    
    // MARK: Configuration
    
    /**
      Configuration options for this resource.
      
      Note that this is a read-only property. You cannot directly change an individual resource's configuration.
      The reason for this is that resource instances are created on demand, and can disappear under memory pressure when
      not in use. Any configuration applied a particular resource instance would therefore be transient.
      
      Instead, you must use the `Service.configure(...)` methods. This sets up configuration to be applied to resources
      according to their URL, whenever they are created or recreated.
    */
    public var config: Configuration
        {
        if configVersion != service.configVersion
            {
            cachedConfig = service.configurationForResource(self)
            configVersion = service.configVersion
            }
        return cachedConfig
        }
    private var cachedConfig: Configuration = Configuration()
    private var configVersion: UInt64 = 0

    
    // MARK: Resource state

    /**
       The latest valid data we have for this resource. May come from a server response, a cache,
       or a local override.
      
       Note that this property represents the __full state__ of the resource. It therefore only holds entities fetched
       with `load()` and `loadIfNeeded()`, not any of the various flavors of `request(...)`.
      
       Note that `latestData` will be present as long as there has _ever_ been a succesful request since the resource
       was created or wiped. If an error occurs, `latestData` will still hold the latest (now stale) valid data.
 
       - SeeAlso: `DataContainer`
    */
    public private(set) var latestData: Entity?
    
    /**
      Details if the last attempt to load this resource resulted in an error. Becomes nil as soon
      as a request is successful.
     
      Note that this only reports error from `load()` and `loadIfNeeded()`, not any of the various
      flavors of `request(...)`.
    */
    public private(set) var latestError: ResourceError?
    
    /// The time of the most recent update to either `latestData` or `latestError`.
    public var timestamp: NSTimeInterval
        {
        return max(
            latestData?.timestamp ?? 0,
            latestError?.timestamp ?? 0)
        }
    
    
    // MARK: Request management
    
    /// True if any requests for this resource are pending.
    public var loading: Bool { return !requests.isEmpty }

    /// All requests in progress related to this resource, in the order they were initiated.
    public private(set) var requests = [Request]()  // TOOD: Any special handling for concurrent POST & GET?
    
    // MARK: -
    
    internal init(service: Service, url: NSURL?)
        {
        self.service = service
        self.url = url?.absoluteURL
        
        super.init()
        
        NSNotificationCenter.defaultCenter().addObserverForName(
                UIApplicationDidReceiveMemoryWarningNotification,
                object: nil,
                queue: nil)
            {
            [weak self] _ in
            self?.cleanDefunctObservers()
            }
        }
    
    // MARK: URL Navigation
    
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
      [`ResourcePathsSpec`](https://github.com/bustoutsolutions/siesta/blob/master/Tests/ResourcePathsSpec.swift)
      for details.
      
      - SeeAlso: `relative(_:)`
    */
    public func child(subpath: String) -> Resource
        {
        return service.resource(url?.URLByAppendingPathComponent(subpath))
        }
    
    /**
      Returns the resource with the given URL, using this resource’s URL as the base if it is a relative URL.
     
      This method interprets strings such as `.`, `..`, and a leading `/` or `//` as relative URLs. It resolves its
      parameter much like an `href` attribute in an HTML document. Refer to
      [`ResourcePathsSpec`](https://github.com/bustoutsolutions/siesta/blob/master/Tests/ResourcePathsSpec.swift)
      for details.
    
      - SeeAlso:
        - `optionalRelative(_:)`
        - `child(_:)`
    */
    public func relative(href: String) -> Resource
        {
        return service.resource(NSURL(string: href, relativeToURL: url))
        }
    
    /**
      Returns `relative(href)` if `href` is present, and nil if `href` is nil.
      
      This convenience method is useful for resolving URLs returned as part of a JSON response body:
      
          let href = resource.dict["owner"]  // href is an optional
          if let ownerResource = resource.optionalRelative(href) {
            // ...
          }
    */
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
    @objc(withParam:value:)
    public func withParam(name: String, _ value: String?) -> Resource
        {
        return service.resource(
            url?.alterQuery
                {
                (var params) in
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
        - `request(_:data:mimeType:requestMutation:)`
        - `request(_:text:encoding:requestMutation:)`
        - `request(_:json:requestMutation:)`
        - `request(_:urlEncoded:requestMutation:)`
    */
    public func request(
            method:          RequestMethod,
            requestMutation: NSMutableURLRequest -> () = { _ in })
        -> Request
        {
        let nsreq = NSMutableURLRequest(URL: url!)  // TODO: remove ! when invalid URLs handled
        nsreq.HTTPMethod = method.rawValue
        requestMutation(nsreq)

        let req = NetworkRequest(resource: self, nsreq: nsreq)

        requests.append(req)
        req.completion
            {
            [weak self, weak req] _ in
            if let resource = self
                { resource.requests = resource.requests.filter { $0 !== req } }
            }
        
        config.willStartRequest(req, forResource: self)
        
        return req.start()
        }
    
    /**
      Convenience method to initiate a request with a body.
    */
    public func request(
            method:          RequestMethod,
            data:            NSData,
            mimeType:        String,
            requestMutation: NSMutableURLRequest -> () = { _ in })
        -> Request
        {
        return request(method)
            {
            nsreq in
            
            nsreq.addValue(mimeType, forHTTPHeaderField: "Content-Type")
            nsreq.HTTPBody = data
            
            requestMutation(nsreq)
            }
        }
    
    /**
      Convenience method to initiate a request with a text body.
      
      If the string cannot be encoded using the given encoding, this methods triggers the `failure(_:)` request hook
      immediately, without touching the network.
      
      - Parameter mimeType: `text/plain` by default.
      - Parameter encoding: UTF-8 (`NSUTF8StringEncoding`) by default.
    */
    public func request(
            method:          RequestMethod,
            text:            String,
            mimeType:        String = "text/plain",
            encoding:        NSStringEncoding = NSUTF8StringEncoding,
            requestMutation: NSMutableURLRequest -> () = { _ in })
        -> Request
        {
        let encodingName = CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(encoding))
        if let rawBody = text.dataUsingEncoding(encoding)
            { return request(method, data: rawBody, mimeType: "\(mimeType); charset=\(encodingName)") }
        else
            {
            return FailedRequest(
                ResourceError(
                    userMessage: "Unable to encode text",
                    debugMessage: "Cannot encode text body using \(encodingName)"))
            }
        }

    /**
      Convenience method to initiate a request with a JSON body.
      
      If the `json` cannot be encoded as JSON, e.g. if it is a dictionary with non-JSON-convertible data, this methods
      triggers the `failure(_:)` request hook immediately, without touching the network.
      
      - Parameter mimeType: `application/json` by default.
    */
    public func request(
            method:          RequestMethod,
            json:            NSJSONConvertible,
            mimeType:        String = "application/json",
            requestMutation: NSMutableURLRequest -> () = { _ in })
        -> Request
        {
        guard NSJSONSerialization.isValidJSONObject(json) else
            {
            return FailedRequest(
                ResourceError(userMessage: "Cannot encode JSON", debugMessage: "Not a valid JSON object"))
            }
        
        do  {
            let rawBody = try NSJSONSerialization.dataWithJSONObject(json, options: [])
            return request(method, data: rawBody, mimeType: mimeType)
            }
        catch
            {
            // Swift doesn’t catch NSInvalidArgumentException, so the isValidJSONObject() method above is necessary
            // to handle the case of non-encodable input. Given that, it's unclear what other circumstances would cause
            // encoding to fail such that dataWithJSONObject() is declared “throws” (radar 21913397, Apple-rejected!),
            // but we catch the exception anyway instead of using try! and crashing.
            
            return FailedRequest(
                ResourceError(userMessage: "Cannot encode JSON", error: error as NSError))
            }
        }
    
    /**
      Convenience method to initiate a request with URL-encoded parameters in the meesage body.
      
      This method performs all necessary escaping, and has full Unicode support in both keys and values.
      
      The content type is `application/x-www-form-urlencoded`.
    */
    public func request(
            method:            RequestMethod,
            urlEncoded params: [String:String],
            requestMutation:   NSMutableURLRequest -> () = { _ in })
        -> Request
        {
        func urlEscape(string: String) -> String
            {
            // Based on https://github.com/Alamofire/Alamofire/blob/338955a54722dea6051ed5c5c76a8736f4195515/Source/ParameterEncoding.swift#L186
            let charsToEscape = ":#[]@!$&'()*+,;="
            return CFURLCreateStringByAddingPercentEscapes(nil, string, nil, charsToEscape, CFStringBuiltInEncodings.UTF8.rawValue)
                as String
            }
        
        let paramString = "&".join(
            params.map { urlEscape($0.0) + "=" + urlEscape($0.1) }.sort())
        return request(method,
            data: paramString.dataUsingEncoding(NSASCIIStringEncoding)!,  // ! reason: ASCII guaranteed safe because of escaping
            mimeType: "application/x-www-form-urlencoded")
        }

    /**
      Initiates a GET request to update the state of this resource, unless it is already up to date.
      
      “Up to date” means that either:
        - the resource has data (i.e. `latestData` is not nil),
        - the last request succeeded (i.e. `latestError` _is_ nil), and
        - the timestamp on `latestData` is more recent than `expirationTime` seconds ago,
      
      …or:
        - the last request failed (i.e. `latestError` is not nil), and
        - the timestamp on `latestError` is more recent than `retryTime` seconds ago.
    
      If the resource is not up to date, this method calls `load()`.
    */
    public func loadIfNeeded() -> Request?
        {
        if(loading)
            {
            debugLog(.Staleness, [self, "loadIfNeeded(): load already in progress"])
            return nil  // TODO: should this return existing request instead?
            }
        
        let maxAge = (latestError == nil)
            ? config.expirationTime
            : config.retryTime
        
        if(now() - timestamp <= maxAge)
            {
            debugLog(.Staleness, [self, "loadIfNeeded(): data still fresh for", maxAge - (now() - timestamp), "more seconds"])
            return nil
            }
        
        debugLog(.Staleness, [self, "loadIfNeeded() triggered load()"])
        return self.load()
        }
    
    /**
      Initiates a GET request to update the state of this resource.
      
      Sequence of events:
    
      1. This resource’s `loading` property becomes true, and remains true until the request either succeeds or fails.
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
            if let etag = self.latestData?.etag
                { nsreq.setValue(etag, forHTTPHeaderField: "If-None-Match") }
            }
        
        req.newData(self.receiveData)
        req.notModified(self.receiveDataNotModified)
        req.failure(self.receiveError)

        self.notifyObservers(.Requested)

        return req
        }
    
    /**
      Directly updates `latestData` without touching the network. Clears `latestError` and broadcasts
      `ResourceEvent.NewData` to observers.
      
      This method is useful in two situations.
      
      ### Alternative to load()
    
      You may want to construct a more complicated request than `load()` allows (e.g. using a method other than
      GET), but still use the response body as the new state of the resource:
         
          let auth = service.resource("login")
          let authData = ["user": username, "pass": password]
          auth.request(method: .POST, json: authData)
            .newData { entity in auth.localEntityOverride(entity) })
      
      ### Incremental updates
    
      You may send a request which does _not_ return the complete state of the resource in the response body,
      but which still changes the state of the resource. You could handle this by initiating a refresh immedately
      after success:
      
          resource.request(method: .POST, json: ["name": "Fred"])
            .success { _ in resource.load() }
      
      However, if you already _know_ the resulting state of the resource given a success response, you can avoid the
      second network call by updating the entity yourself:
      
          resource.request(method: .POST, json: ["name": "Fred"])
            .success { partialEntity in
                
                // Make a mutable copy of the current entity
                var updatedEntity = resource.latestData
                var updatedPayload = resource.dict
                
                // Do the incremental update
                updatedPayload["name"] = parialEntity["newName"]
                updatedEntity.payload = updatedPayload
    
                // Make that the resource’s new entity
                resource.localEntityOverride(updatedEntity)
            }
    
      Use this technique with caution!
      
      Note that the data you pass does _not_ go through the standard `ResponseTransformer` chain. You should pass data
      as if it was already parsed, not in its raw form as the server would return it. For example, in the code above,
      `updatedPayload` is a `Dictionary`, not `NSData` containing encoded JSON.
    */
    public func localEntityOverride(entity: Entity)
        { receiveNewData(entity, localOverride: true) }
    
    private func receiveData(entity: Entity)
        { receiveNewData(entity, localOverride: false) }
    
    private func receiveNewData(entity: Entity, localOverride: Bool)
        {
        debugLog(.StateChanges, [self, "received new data from", localOverride ? "a local override:" : "the network:", entity])
        
        self.latestError = nil
        self.latestData = entity
        
        notifyObservers(.NewData)
        }

    private func receiveDataNotModified()
        {
        debugLog(.StateChanges, [self, "existing data is still valid"])
        
        self.latestError = nil
        self.latestData?.touch()
        
        notifyObservers(.NotModified)
        }
    
    private func receiveError(error: ResourceError)
        {
        if let nserror = error.nsError
            where nserror.domain == NSURLErrorDomain
               && nserror.code == NSURLErrorCancelled
            {
            notifyObservers(.RequestCancelled)
            return
            }

        debugLog(.StateChanges, [self, "received error:", error])
        
        self.latestError = error

        notifyObservers(.Error)
        }
    
    /**
      Resets this resource to its pristine state, as if newly created.
    
      - Sets `latestData` to nil.
      - Sets `latestError` to nil.
      - Cancels all resource requests in progress.
      
      Observers receive a `NewData` event. Requests in progress call completion hooks with a cancellation error.
    */
    public func wipe()
        {
        debugLog(.StateChanges, [self, "wiped"])
        
        self.latestError = nil
        self.latestData = nil
        
        for request in requests
            { request.cancel() }
        
        notifyObservers(.NewData)
        }
    
    // MARK: Debug
    
    /// :nodoc:
    public override var debugDescription: String
        {
        return "Siesta.Resource("
            + debugStr(url)
            + ")["
            + (loading ? "L" : "")
            + (latestData != nil ? "D" : "")
            + (latestError != nil ? "E" : "")
            + "]"
        }
    }

/// Dictionaries and arrays can both be passed to `Resource.request(_:json:mimeType:requestMutation:)`.
public protocol NSJSONConvertible: AnyObject { }
extension NSDictionary: NSJSONConvertible { }
extension NSArray:      NSJSONConvertible { }
