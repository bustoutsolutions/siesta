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

public typealias ResourceObserverClosure = (resource: Resource, event: ResourceEvent) -> ()
public typealias ResourceProgressObserverClosure = (resource: Resource) -> ()

public enum ResourceEvent: String
    {
    case ObserverAdded  // Sent only to the newly attached observer, not all observers
    case Requested
    case RequestCancelled
    case NewDataResponse
    case NotModifiedResponse
    case ErrorResponse
    }


public extension Resource
    {
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
    
    @objc(removeObserversOwnedBy:)
    public func removeObservers(ownedBy owner: AnyObject?) -> Int
        {
        let removed = observers.filter { $0.owner === owner }
        observers = observers.filter { $0.owner !== owner }
        for entry in removed
            { entry.observer?.stoppedObservingResource(self) }
        return removed.count
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
        let removedCount = removeObservers(ownedBy: nil)
        if removedCount > 0
            { debugLog([self, "removed", removedCount, "observers whose owners were deallocated"]) }
        }
    }

// MARK: - Internals

internal protocol ObserverEntry
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
