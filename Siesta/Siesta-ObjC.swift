//
//  Siesta-ObjC.swift
//  Siesta
//
//  Glue for using Siesta from Objective-C, quarrantined for readability.
//
//  Created by Paul on 2015/7/14.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

// MARK: - …because load methods return Alamofire objects

public extension Resource
    {
    @objc(load)         public func loadObjc() { self.load() }
    @objc(loadIfNeeded) public func loadIfNeededObjc() { self.loadIfNeeded() }
    }

// MARK: - …because ResourceEvent is an enum

@objc(BOSResourceObserver)
public protocol ResourceObserverObjc
    {
    func resourceChanged(resource: Resource, event: String)
    optional func resourceRequestProgress(resource: Resource)
    optional func stoppedObservingResource(resource: Resource)
    }

private class ResourceObserverObjcGlue: ResourceObserver
    {
    let objcObserver: ResourceObserverObjc
    
    init(objcObserver: ResourceObserverObjc)
        { self.objcObserver = objcObserver }

    func resourceChanged(resource: Resource, event: ResourceEvent)
        { objcObserver.resourceChanged(resource, event: event.rawValue) }
    
    func resourceRequestProgress(resource: Resource)
        { objcObserver.resourceRequestProgress?(resource) }
    
    func stoppedObservingResource(resource: Resource)
        { objcObserver.stoppedObservingResource?(resource) }
    }

public extension Resource
    {
    public func addObserver(objcObserverAndOwner: protocol<ResourceObserverObjc, AnyObject>) -> Self
        { return addObserver(ResourceObserverObjcGlue(objcObserver: objcObserverAndOwner)) }

    public func addObserver(objcObserver: ResourceObserverObjc, owner: AnyObject) -> Self
        { return addObserver(ResourceObserverObjcGlue(objcObserver: objcObserver), owner: owner) }
    }

extension ResourceStatusOverlay: ResourceObserverObjc
    {
    public func resourceChanged(resource: Resource, event: String)
        { self.resourceChanged(resource, event: ResourceEvent(rawValue: event)!) }
    }

