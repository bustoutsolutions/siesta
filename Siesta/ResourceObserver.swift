//
//  ResourceObserver.swift
//  Siesta
//
//  Created by Paul on 2015/6/29.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

// MARK: - Observer API

public protocol ResourceObserver
    {
    func resourceChanged(resource: Resource, event: ResourceEvent)
    func resourceRequestProgress(resource: Resource)
    func stoppedObservingResource(resource: Resource)
    }

public extension ResourceObserver
    {
    func resourceRequestProgress(resource: Resource) { }
    func stoppedObservingResource(resource: Resource) { }
    }

public enum ResourceEvent: String
    {
    case ObserverAdded  // Sent only to the newly attached observer, not all observers
    case Requested
    case RequestCancelled
    case NewDataResponse
    case NotModifiedResponse
    case ErrorResponse
    }

public typealias ResourceObserverClosure = (resource: Resource, event: ResourceEvent) -> ()

public extension Resource
    {
    /**
        Adds an observer without retaining a reference to it.
    */
    public func addObserver(observerAndOwner: protocol<ResourceObserver, AnyObject>) -> Self
        {
        return addObserver(observerAndOwner, owner: observerAndOwner)
        }
    
    public func addObserver(observer: ResourceObserver, owner: AnyObject) -> Self
        {
        if let observerObj = observer as? AnyObject
            {
            for (i, entry) in observers.enumerate()
                where entry.observer != nil
                   && observerObj === (entry.observer as? AnyObject)
                    {
                    // have to use observers[i] instead of loop var to
                    // make mutator actually change struct in place in array
                    observers[i].addOwner(owner)
                    return self
                    }
            }
        
        var newEntry = ObserverEntry(observer: observer, resource: self)
        newEntry.addOwner(owner)
        observers.append(newEntry)
        observer.resourceChanged(self, event: .ObserverAdded)
        return self
        }
    
    public func addObserver(owner owner: AnyObject, closure: ResourceObserverClosure) -> Self
        {
        return addObserver(ClosureObserver(closure: closure), owner: owner)
        }
    
    @objc(removeObserversOwnedBy:)
    public func removeObservers(ownedBy owner: AnyObject?)
        {
        guard let owner = owner else
            { return }
        
        for i in observers.indices
            { observers[i].removeOwner(owner) }
        
        cleanDefunctObservers()
        }
    
    internal func notifyObservers(event: ResourceEvent)
        {
        cleanDefunctObservers()
        
        debugLog([self, "sending", event, "to", observers.count, "observers"])
        for entry in observers
            {
            debugLog([self, "sending", event, "to", entry.observer])
            entry.observer?.resourceChanged(self, event: event)
            }
        }
    
    internal func cleanDefunctObservers()
        {
        for i in observers.indices
            { observers[i].cleanUp() }
        
        let (removed, kept) = observers.bipartition { $0.isDefunct }
        observers = kept
        
        for entry in removed
            {
            debugLog([self, "removing observer whose owners are all gone:", entry.observer ?? "<observer deallocated>"])
            entry.observer?.stoppedObservingResource(self)
            }
        }
    }


// MARK: - Internals

internal struct ObserverEntry
    {
    private let resource: Resource  // keeps resource around as long as it has observers
    
    private var observerRef: StrongOrWeakRef<ResourceObserver>  // strong iff there are external owners
    var observer: ResourceObserver?
        { return observerRef.value }
    
    private var externalOwners = Set<WeakRef<AnyObject>>()
    private var observerIsOwner: Bool = false

    init(observer: ResourceObserver, resource: Resource)
        {
        self.observerRef = StrongOrWeakRef<ResourceObserver>(observer)
        self.resource = resource
        }

    mutating func addOwner(owner: AnyObject)
        {
        if owner === (observer as? AnyObject)
            { observerIsOwner = true }
        else
            { externalOwners.insert(WeakRef(owner)) }
        cleanUp()
        }
    
    mutating func removeOwner(owner: AnyObject)
        {
        if owner === (observer as? AnyObject)
            { observerIsOwner = false }
        else
            { externalOwners.remove(WeakRef(owner)) }
        cleanUp()
        }
    
    mutating func cleanUp()
        {
        // Look for weak refs which refer to objects that are now gone
        externalOwners = Set(externalOwners.filter { $0.value != nil })  // TODO: improve performance (Can Swift modify Set in place while iterating?)
        
        observerRef.strong = !externalOwners.isEmpty
        }
    
    var isDefunct: Bool
        {
        return observer == nil
            || (!observerIsOwner && externalOwners.isEmpty)
        }
    }

private struct ClosureObserver: ResourceObserver
    {
    private let closure: ResourceObserverClosure
    
    func resourceChanged(resource: Resource, event: ResourceEvent)
        {
        closure(resource: resource, event: event)
        }
    }
