//
//  ResourceObserver.swift
//  Siesta
//
//  Created by Paul on 2015/6/29.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

/**
  Something that can observe changes to the state of a `Resource`.
*/
public protocol ResourceObserver
    {
    /**
      Called when anything happens that might change the value of the reosurce’s `latestData`, `latestError`, or
      `loading` flag. The `event` explains the reason for the notification.
    */
    func resourceChanged(resource: Resource, event: ResourceEvent)
    
    /// :nodoc:
    func resourceRequestProgress(resource: Resource) // TODO: not implemented yet
    
    /**
      Called when this observer stops observering a resource. Use for making `removeObservers(ownedBy:)` trigger
      other cleanup.
    */
    func stoppedObservingResource(resource: Resource)
    }

public extension ResourceObserver
    {
    /// :nodoc:
    func resourceRequestProgress(resource: Resource) { }

    /// Does nothing.
    func stoppedObservingResource(resource: Resource) { }
    }

/**
  A closure alternative to `ResourceObserver`.
  
  See `Resource.addObserver(owner:closure:)`.
*/
public typealias ResourceObserverClosure = (resource: Resource, event: ResourceEvent) -> ()

/**
  The possible causes of a call to `ResourceObserver.resourceChanged(_:event:)`.
  
  - SeeAlso: `Resource.load()`
*/
public enum ResourceEvent: String
    {
    /**
      Immediately sent to a new observer when it first starts observering a resource. This event allows you to gather
      all of your “update UI from resource state” code in one place, and have that code be called both when the UI first
      appears _and_ when the resource state changes.
    
      Note that this is sent only to the newly attached observer, not all observers.
    */
    case ObserverAdded
    
    /// A load request for this resource started. `Resource.loading` is now true.
    case Requested
    
    /// The request in progress was cancelled before it finished.
    case RequestCancelled
    
    /// The resource’s `latestData` property has been updated.
    case NewData
    
    /// The request in progress succeeded, but did not result in a change to the resource’s `latestData` (except
    /// the timestamp). Note that you may still need to update the UI, because if `latestError` was present before, it
    /// is now nil.
    case NotModified

    /// The request in progress failed. Details are in the resource’s `latestError` property.
    case Error
    }

public extension Resource
    {
    // MARK: - Observing Resources

    /**
      Adds an self-owned observer to this resource, which will receive notifications of changes to resource state.
      
      The resource holds a weak reference to the observer. If there are no strong references to the observer, it is
      automatically removed.
      
      Use this method for objects such as `UIViewController`s which already have a lifecycle of their own, are retained
      elsewhere, and also happen to act as observers.
    */
    public func addObserver(observerAndOwner: protocol<ResourceObserver, AnyObject>) -> Self
        {
        return addObserver(observerAndOwner, owner: observerAndOwner)
        }
    
    /**
      Adds an observer to this resource, holding a strong reference to it as long as `owner` still exists.
    
      The resource holds only a weak reference to `owner`, and as soon as the owner goes away, the observer is removed.
      
      The typical use for this method is for glue objects whose only purpose is to act as an observer, and which would
      not normally be retained by anything else.
    */
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
    
    /**
      Adds a closure observer to this resource.

      The resource holds a weak reference to `owner`, and the closure will receive events only as long as `owner`
      still exists.
    */
    public func addObserver(owner owner: AnyObject, closure: ResourceObserverClosure) -> Self
        {
        return addObserver(ClosureObserver(closure: closure), owner: owner)
        }
    
    /**
      Removes all observers owned by the given object.
    */
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
        
        debugLog(.Observers, [self, "sending", event, "to", observers.count, "observers"])
        for entry in observers
            {
            debugLog(.Observers, [self, "sending", event, "to", entry.observer])
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
            debugLog(.Observers, [self, "removing observer whose owners are all gone:", entry.observer ?? "<observer deallocated>"])
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
