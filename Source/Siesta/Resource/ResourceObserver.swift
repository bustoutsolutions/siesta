//
//  ResourceObserver.swift
//  Siesta
//
//  Created by Paul on 2015/6/29.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

/**
  Something that can observe changes to the state of a `Resource`.
  “State” means `latestData`, `latestError`, and `isLoading`.

  Any code that wants to display or process a resource’s content should register itself as an observer using
  `Resource.addObserver(...)`.
*/
public protocol ResourceObserver
    {
    /**
      Called when anything happens that might change the value of the reosurce’s `latestData`, `latestError`, or
      `isLoading` flag. The `event` explains the reason for the notification.
    */
    func resourceChanged(resource: Resource, event: ResourceEvent)

    /**
      Receive updates on progress at regular intervals while a request is in progress.
      Will _always_ receive a call with a value of 1 when the request completes.
    */
    func resourceRequestProgress(resource: Resource, progress: Double)

    /**
      Called when this observer stops observing a resource. Use for making `removeObservers(ownedBy:)` trigger
      other cleanup.
    */
    func stoppedObservingResource(resource: Resource)

    /**
      Allows you to prevent redundant observers from being added to the same resource. If an existing observer
      says it is equivalent to a new observer passed to `Resource.addObserver(...)`, then the call has no effect.
    */
    @warn_unused_result
    func isEquivalentToObserver(other: ResourceObserver) -> Bool
    }

public extension ResourceObserver
    {
    /// Does nothing.
    func resourceRequestProgress(resource: Resource, progress: Double) { }

    /// Does nothing.
    func stoppedObservingResource(resource: Resource) { }

    /// True iff self and other are (1) both objects and (2) are the _same_ object.
    func isEquivalentToObserver(other: ResourceObserver) -> Bool
        {
        if let selfObj = self as? AnyObject,
           let otherObj = other as? AnyObject
            { return selfObj === otherObj }
        else
            { return false }
        }
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
public enum ResourceEvent: CustomStringConvertible
    {
    /**
      Immediately sent to a new observer when it first starts observing a resource. This event allows you to gather
      all of your “update UI from resource state” code in one place, and have that code be called both when the UI first
      appears _and_ when the resource state changes.

      Note that this is sent only to the newly attached observer, not all observers.
    */
    case ObserverAdded

    /// A load request for this resource started. `Resource.isLoading` is now true.
    case Requested

    /// The request in progress was cancelled before it finished.
    case RequestCancelled

    /// The resource’s `latestData` property has been updated.
    case NewData(NewDataSource)

    /// The request in progress succeeded, but did not result in a change to the resource’s `latestData` (except
    /// the timestamp). Note that you may still need to update the UI, because if `latestError` was present before, it
    /// is now nil.
    case NotModified

    /// The request in progress failed. Details are in the resource’s `latestError` property.
    case Error

    /// :nodoc:
    public var description: String
        {
        // If anyone knows a way around this monstrosity, please send me a PR. -PPC
        switch self
            {
            case ObserverAdded:       return "ObserverAdded"
            case Requested:           return "Requested"
            case RequestCancelled:    return "RequestCancelled"
            case NewData(let source): return "NewData(\(source))"
            case NotModified:         return "NotModified"
            case Error:               return "Error"
            }
        }

    internal static let all = [ObserverAdded, Requested, RequestCancelled, NotModified, Error,
                               NewData(.Network), NewData(.Cache), NewData(.LocalOverride), NewData(.Wipe)]

    internal static func fromDescription(description: String) -> ResourceEvent?
        {
        let matching = all.filter { $0.description == description }
        return (matching.count == 1) ? matching[0] : nil
        }

    /// Possible sources of `ResourceEvent.NewData`.
    public enum NewDataSource
        {
        /// The new value of `latestData` comes from a successful network request.
        case Network

        /// The new value of `latestData` comes from this resource’s `Configuration.persistentCache`.
        case Cache

        /// The new value of `latestData` came from a call to `Resource.overrideLocalData(_:)`
        case LocalOverride

        /// The resource was wiped, and `latestData` is now nil.
        case Wipe
        }
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

      - Note: This method prevents duplicates; adding the same observer object a second time has no effect. This is
              _not_ necessarily true of other flavors of `addObserver`, which accept observers that are not objects.
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

      - Note: By default, this method prevents duplicates **only if the observer is an object**. If you pass a struct
              twice, you will receive two calls for every event. This is because only objects have a notion of identity
              in Swift. You can implement `ResourceObserver.isEquivalentToObserver(_:)` to make a struct prevent
              duplicates; however, it’s usually easier to ensure that you don’t make redundant calls to this method if
              you’re passing a struct.
    */
    public func addObserver(observer: ResourceObserver, owner: AnyObject) -> Self
        {
        for (i, entry) in observers.enumerate()
            {
            if let existingObserver = entry.observer
                where existingObserver.isEquivalentToObserver(observer)
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

      - Note: Unlike the `addObserver(_:)` that takes objects, this method does not prevent duplicates. If you pass a
              closure twice, it will be called twice for every event. It has to be this way, because Swift has no notion
              of closure identity: there is no such thing as “the same” closure in the language, and thus no way to
              detect duplicates. It is thus the caller’s responsibility to prevent redundant calls to this method.
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

    internal var beingObserved: Bool
        {
        cleanDefunctObservers()
        return !observers.isEmpty
        }

    internal func notifyObservers(event: ResourceEvent)
        {
        cleanDefunctObservers()

        debugLog(.Observers, [self, "sending", event, "to", observers.count, "observer" + (observers.count == 1 ? "" : "s")])
        for entry in observers
            {
            debugLog(.Observers, [self, "sending", event, "to", entry.observer])
            entry.observer?.resourceChanged(self, event: event)
            }
        }

    internal func notifyObservers(progress progress: Double)
        {
        for entry in observers
            {
            entry.observer?.resourceRequestProgress(self, progress: progress)
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
            debugLog(.Observers, [self, "removing observer whose owners are all gone:", entry])
            entry.observer?.stoppedObservingResource(self)
            }
        }
    }


// MARK: - Internals

internal struct ObserverEntry: CustomStringConvertible
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
        originalObserverDescription = debugStr(observer)  // So we know what was deallocated if it gets logged
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
        externalOwners.filterInPlace { $0.value != nil }

        observerRef.strong = !externalOwners.isEmpty
        }

    var isDefunct: Bool
        {
        return observer == nil
            || (!observerIsOwner && externalOwners.isEmpty)
        }

    private var originalObserverDescription: String
    var description: String
        {
        if let observer = observer
            { return debugStr(observer) }
        else
            { return "<deallocated: \(originalObserverDescription)>" }
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
