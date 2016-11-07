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
    func resourceChanged(_ resource: Resource, event: ResourceEvent)

    /**
      Receive updates on progress at regular intervals while a request is in progress.
      Will _always_ receive a call with a value of 1 when the request completes.
    */
    func resourceRequestProgress(for resource: Resource, progress: Double)

    /**
      Called when this observer stops observing a resource, if the observer itself still exists.
      Use for making `Resource.removeObservers(ownedBy:)` trigger other cleanup.

      - Warning: This method is **not** called for self-owned observers when the observer itself being deallocated is
          what caused it to stop observing. This is because there is no way for Siesta to know that observer is _about_
          to be deallocated; it can only check whether the observer is already gone.

          For example:

              var myObserver: MyObserver? = MyObserver()
              resource.addObserver(myObserver!)  // myObserver is self-owned, so...
              myObserver = nil                   // this deallocates it, but...
              // ...myObserver never receives stoppedObserving(resource:).

          In the situation above, `MyObserver` should implement any end-of-lifcycle cleanup using `deinit`.
    */
    func stoppedObserving(resource: Resource)

    /**
      Allows you to prevent redundant observers from being added to the same resource. If an existing observer
      has an identity equals to a new observer, then `Resource.addObserver(...)` has no effect.
    */
    var observerIdentity: AnyHashable { get }
    }

struct UniqueObserverIdentity: Hashable
    {
    private static var idSeq = 0
    private let id: Int

    init()
        {
        id = UniqueObserverIdentity.idSeq
        UniqueObserverIdentity.idSeq += 1
        }

    static func == (lhs: UniqueObserverIdentity, rhs: UniqueObserverIdentity) -> Bool
        {
        return lhs.id == rhs.id
        }

    var hashValue: Int
        { return id }
    }

public extension ResourceObserver
    {
    /// Does nothing.
    func resourceRequestProgress(for resource: Resource, progress: Double) { }

    /// Does nothing.
    func stoppedObserving(resource: Resource) { }

    /// True iff self and other are (1) both objects and (2) are the _same_ object.
    var observerIdentity: AnyHashable
        {
        if isObject(self)
            { return AnyHashable(ObjectIdentifier(self as AnyObject)) }
        else
            { return UniqueObserverIdentity() }
        }
    }

/**
  A closure alternative to `ResourceObserver`.

  See `Resource.addObserver(owner:file:line:closure:)`.
*/
public typealias ResourceObserverClosure = (Resource, ResourceEvent) -> ()

/**
  The possible causes of a call to `ResourceObserver.resourceChanged(_:event:)`.

  - SeeAlso: `Resource.load()`
*/
public enum ResourceEvent
    {
    /**
      Immediately sent to a new observer when it first starts observing a resource. This event allows you to gather
      all of your “update UI from resource state” code in one place, and have that code be called both when the UI first
      appears _and_ when the resource state changes.

      Note that this is sent only to the newly attached observer, not all observers.
    */
    case observerAdded

    /// A load request for this resource started. `Resource.isLoading` is now true.
    case requested

    /// The request in progress was cancelled before it finished.
    case requestCancelled

    /// The resource’s `latestData` property has been updated.
    case newData(NewDataSource)

    /// The request in progress succeeded, but did not result in a change to the resource’s `latestData` (except
    /// the timestamp). Note that you may still need to update the UI, because if `latestError` was present before, it
    /// is now nil.
    case notModified

    /// The request in progress failed. Details are in the resource’s `latestError` property.
    case error

    /// Possible sources of `ResourceEvent.newData`.
    public enum NewDataSource: String, CustomStringConvertible
        {
        /// The new value of `latestData` comes from a successful network request.
        case network

        /// The new value of `latestData` comes from an `EntityCache`.
        case cache

        /// The new value of `latestData` came from a call to `Resource.overrideLocalData(...)`.
        case localOverride

        /// The resource was wiped, and `latestData` is now nil.
        case wipe

        public var description: String
            { return rawValue }
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
    @discardableResult
    public func addObserver(_ observerAndOwner: ResourceObserver & AnyObject) -> Self
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
              in Swift. You can implement `ResourceObserver.observerIdentity` to make a struct prevent duplicates;
              however, it’s usually easier to ensure that you don’t make redundant calls to this method if you’re
              passing a struct.
    */
    @discardableResult
    public func addObserver(_ observer: ResourceObserver, owner: AnyObject) -> Self
        {
        let identity = observer.observerIdentity

        // An existing observer may be a false positive, already removed but
        // pending cleanup. If we find one, force cleanup before we decide not
        // to broadcast observerAdded.

        cleanDefunctObservers(force: observers[identity] != nil)

        if let existingEntry = observers[identity]
            {
            existingEntry.addOwner(owner)
            observersChanged()
            return self
            }

        let newEntry = ObserverEntry(observer: observer, resource: self)
        newEntry.addOwner(owner)
        observers[identity] = newEntry
        observer.resourceChanged(self, event: .observerAdded)
        observersChanged()
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
    @discardableResult
    public func addObserver(
            owner: AnyObject,
            file: String = #file,
            line: Int = #line,
            closure: @escaping ResourceObserverClosure)
        -> Self
        {
        return addObserver(
            ClosureObserver(
                closure: closure,
                debugDescription: "ClosureObserver(\(conciseSourceLocation(file: file, line: line)))"),
            owner: owner)
        }

    /**
      Removes all observers owned by the given object.
    */
    @objc(removeObserversOwnedBy:)
    public func removeObservers(ownedBy owner: AnyObject?)
        {
        guard let owner = owner else
            { return }

        for observer in observers.values
            { observer.removeOwner(owner) }

        cleanDefunctObservers()
        }

    internal var beingObserved: Bool
        {
        cleanDefunctObservers(force: true)
        return !observers.isEmpty
        }

    internal func notifyObservers(_ event: ResourceEvent)
        {
        cleanDefunctObservers(force: true)

        debugLog(.observers, [self, "sending", event, "event to", observers.count, "observer" + (observers.count == 1 ? "" : "s")])
        for entry in observers.values
            {
            debugLog(.observers, ["  ↳", event, "→", entry.observer])
            entry.observer?.resourceChanged(self, event: event)
            }
        }

    internal func notifyObservers(progress: Double)
        {
        for entry in observers.values
            {
            entry.observer?.resourceRequestProgress(for: self, progress: progress)
            }
        }

    fileprivate func cleanDefunctObservers(force: Bool = false)
        {
        // There’s a tradeoff between the cost of touching all the weak owner refs of all
        // the observers and the cost of letting the observer list grow. As a compromise,
        // for operations that may modify the observer list but don’t need it to be fully
        // pruned right away, we batch up checks for defunct observers as a delayed main
        // thread task — unless we’re seeing a _lot_ of churn, in which case we force the
        // check to keep the list from growing.

        if !force && delayDefunctObserverCheck()
            { return }
        defunctObserverCheckCounter = 0

        for observer in observers.values
            { observer.cleanUp() }

        if observers.removeValues(matching: { $0.isDefunct })
            { observersChanged() }
        }

    private func delayDefunctObserverCheck() -> Bool  // false means do it now!
        {
        guard defunctObserverCheckCounter < 12 else
            { return false }
        defunctObserverCheckCounter += 1

        if !defunctObserverCheckScheduled
            {
            defunctObserverCheckScheduled = true
            DispatchQueue.main.async
                {
                self.defunctObserverCheckScheduled = false
                self.cleanDefunctObservers(force: true)
                }
            }

        return true
        }
    }


// MARK: - Internals

internal class ObserverEntry: CustomStringConvertible
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
        if LogCategory.enabled.contains(.observers)
            { originalObserverDescription = debugStr(observer) }  // So we know what was deallocated if it gets logged
        }

    deinit
        {
        debugLog(.observers, ["removing observer of", resource, "whose owners are all gone:", self])
        observer?.stoppedObserving(resource: resource)
        }

    func addOwner(_ owner: AnyObject)
        {
        withOwner(owner,
            ifObserver:
                { observerIsOwner = true },
            else:
                { externalOwners.insert(WeakRef(owner)) })
        }

    func removeOwner(_ owner: AnyObject)
        {
        withOwner(owner,
            ifObserver:
                { observerIsOwner = false },
            else:
                { externalOwners.remove(WeakRef(owner)) })
        }

    private func withOwner(
            _ owner: AnyObject,
            ifObserver selfOwnerAction: (Void) -> Void,
            else externalOwnerAction: (Void) -> Void)
        {
        // TODO: see if isObject() check improves perf here once https://bugs.swift.org/browse/SR-2867 is fixed
        if owner === (observer as AnyObject?)
            { selfOwnerAction() }
        else
            { externalOwnerAction() }
        cleanUp()
        }

    func cleanUp()
        {
        // Look for weak refs which refer to objects that are now gone
        externalOwners.filterInPlace { $0.value != nil }

        observerRef.strong = !observerIsOwner || !externalOwners.isEmpty
        }

    var isDefunct: Bool
        {
        return observer == nil
            || (!observerIsOwner && externalOwners.isEmpty)
        }

    private var originalObserverDescription: String?
    var description: String
        {
        if let observer = observer
            { return debugStr(observer) }
        else
            { return "<deallocated: \(originalObserverDescription ?? "–")>" }
        }
    }

private struct ClosureObserver: ResourceObserver, CustomDebugStringConvertible
    {
    let closure: ResourceObserverClosure
    let debugDescription: String

    func resourceChanged(_ resource: Resource, event: ResourceEvent)
        {
        closure(resource, event)
        }
    }

extension Resource: WeakCacheValue
    {
    func allowRemovalFromCache()
        { cleanDefunctObservers() }
    }
