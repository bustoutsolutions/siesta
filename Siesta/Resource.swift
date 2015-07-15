//
//  Resource.swift
//  Siesta
//
//  Created by Paul on 2015/6/16.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Alamofire

// Overridable for testing
internal var now = { return NSDate.timeIntervalSinceReferenceDate() }

@objc(BOSResource)
public class Resource: CustomDebugStringConvertible
    {
    // MARK: Configuration
    
    public let service: Service
    public let url: NSURL? // TODO: figure out what to do about invalid URLs
    
    // MARK: Request management
    
    public var loading: Bool { return !loadRequests.isEmpty }
    public private(set) var loadRequests = Set<Request>()  // TOOD: How to handle concurrent POST & GET?
    
    public var expirationTime: NSTimeInterval?
    public var retryTime: NSTimeInterval?
    
    // MARK: Resource state

    public private(set) var latestData: Data?
    public private(set) var latestError: Error?
    public var timestamp: NSTimeInterval
        {
        return max(
            latestData?.timestamp ?? 0,
            latestError?.timestamp ?? 0)
        }
    
    // MARK: Data convenience accessors

    public var data: AnyObject? { return latestData?.payload }
    
    public func typedData<T>(blankValue: T) -> T
        {
        return (data as? T) ?? blankValue
        }
    
    public var json: [String:AnyObject] { return typedData([:]) }
    public var text: String             { return typedData("") }

    // MARK: Observers

    private var observers = [ObserverEntry]()
    
    // MARK: -
    
    init(service: Service, url: NSURL?)
        {
        self.service = service
        self.url = url?.absoluteURL
        
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
    
    public func child(path: String) -> Resource
        {
        return service.resource(url?.URLByAppendingPathComponent(path))
        }
    
    public func relative(path: String) -> Resource
        {
        return service.resource(NSURL(string: path, relativeToURL: url))
        }
    
    // MARK: Requests
    
    public func request(
            method:          Alamofire.Method,
            requestMutation: NSMutableURLRequest -> () = { _ in })
        -> Request
        {
        let nsreq = NSMutableURLRequest(URL: url!)
        nsreq.HTTPMethod = method.rawValue
        requestMutation(nsreq)
        debugLog([nsreq.HTTPMethod, nsreq.URL])

        return service.sessionManager.request(nsreq)
            .response
                {
                nsreq, nsres, payload, nserror in
                debugLog([nsres?.statusCode, "←", nsreq?.HTTPMethod, nsreq?.URL])
                }
        }
    
    public func loadIfNeeded() -> Request?
        {
        if(loading)
            {
            debugLog([self, "loadIfNeeded(): is up to date; no need to load"])
            return nil
            }
        
        let maxAge = (latestError == nil)
            ? expirationTime ?? service.defaultExpirationTime
            : retryTime      ?? service.defaultRetryTime
        
        if(now() - timestamp <= maxAge)
            {
            debugLog([self, "loadIfNeeded(): data still fresh for", maxAge - (now() - timestamp), "more seconds"])
            return nil
            }
        
        debugLog([self, "loadIfNeeded() triggered load()"])
        return self.load()
        }
    
    public func load() -> Request
        {
        let req = request(.GET)
            {
            nsreq in
            if let etag = self.latestData?.etag
                { nsreq.setValue(etag, forHTTPHeaderField: "If-None-Match") }
            }
        loadRequests.insert(req)
        
        req.response
            {
            [weak self, weak req] _ in
            if let req = req
                { self?.loadRequests.remove(req) }
            }
        
        req.resourceResponse(self,
            success:     self.updateStateWithData,
            notModified: self.updateStateWithDataNotModified,
            error:       self.updateStateWithError)

        self.notifyObservers(.Requested)

        return req
        }
    
    private func updateStateWithData(data: Data)
        {
        debugLog([self, "has new data:", data])
        
        self.latestError = nil
        self.latestData = data
        
        notifyObservers(.NewDataResponse)
        }

    private func updateStateWithDataNotModified()
        {
        debugLog([self, "existing data is still valid"])
        
        self.latestError = nil
        self.latestData?.touch()
        
        notifyObservers(.NotModifiedResponse)
        }
    
    private func updateStateWithError(error: Error)
        {
        if let nserror = error.nsError
            where nserror.domain == "NSURLErrorDomain"
               && nserror.code == NSURLErrorCancelled
            {
            notifyObservers(.RequestCancelled)
            return
            }

        debugLog([self, "received error:", error])
        
        self.latestError = error

        notifyObservers(.ErrorResponse)
        }

    // MARK: Observers
    
    /**
        Adds an observer without retaining a reference to it.
    */
    public func addObserver(observerAndOwner: protocol<ResourceObserver, AnyObject>) -> Self
        {
        return addObserverEntry(
            SelfOwnedObserverEntry(resource: self, observerAndOwner: observerAndOwner))
        }
    
    public func addObserver(observer: ResourceObserver, owner: AnyObject) -> Self
        {
        return addObserverEntry(
            SeparateOwnerObserverEntry(resource: self, observer: observer, owner: owner))
        }
    
    public func addObserver(owner: AnyObject, closure: ResourceObserverClosure) -> Self
        {
        return addObserver(ClosureObserver(closure: closure), owner: owner)
        }
    
    private func addObserverEntry(entry: ObserverEntry) -> Self
        {
        observers.append(entry)
        entry.observer?.resourceChanged(self, event: .ObserverAdded)
        return self
        }
    
    public func removeObservers(ownedBy owner: AnyObject?) -> Int
        {
        let removed = observers.filter { $0.owner === owner }
        observers = observers.filter { $0.owner !== owner }
        for entry in removed
            { entry.observer?.stoppedObservingResource(self) }
        return removed.count
        }
    
    private func notifyObservers(event: ResourceEvent)
        {
        cleanDefunctObservers()
        
        debugLog([self, "sending", event, "to", observers.count, "observers"])
        for entry in observers
            {
            debugLog([self, "sending", event, "to", entry.observer])
            entry.observer?.resourceChanged(self, event: event)
            }
        }
    
    private func cleanDefunctObservers()
        {
        let removedCount = removeObservers(ownedBy: nil)
        if removedCount > 0
            { debugLog([self, "removed", removedCount, "observers whose owners were deallocated"]) }
        }
    
    // MARK: Debug
    
    public var debugDescription: String
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


private protocol ObserverEntry
    {
    var observer: ResourceObserver? { get }
    var owner: AnyObject? { get }
    }

private struct SelfOwnedObserverEntry: ObserverEntry
    {
    // Intentional reference cycle to keep Resource alive as long
    // as it has observers.
    let resource: Resource
    
    weak var observerAndOwner: protocol<ResourceObserver,AnyObject>?
    var observer: ResourceObserver? { return observerAndOwner }
    var owner:    AnyObject?        { return observerAndOwner }
    }

private struct SeparateOwnerObserverEntry: ObserverEntry
    {
    let resource: Resource
    
    let observer: ResourceObserver?
    weak var owner: AnyObject?
    }

private struct ClosureObserver: ResourceObserver
    {
    private let closure: ResourceObserverClosure
    
    func resourceChanged(resource: Resource, event: ResourceEvent)
        {
        closure(resource: resource, event: event)
        }
    }
