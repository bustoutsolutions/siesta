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
    @objc(load)         public func _objc_load() { self.load() }
    @objc(loadIfNeeded) public func _objc_loadIfNeeded() { self.loadIfNeeded() }
    }

// MARK: - …because ResourceEvent is an enum

@objc(BOSResourceObserver)
public protocol _objc_ResourceObserver
    {
    func resourceChanged(resource: Resource, event: String)
    optional func resourceRequestProgress(resource: Resource)
    optional func stoppedObservingResource(resource: Resource)
    }

private class _objc_ResourceObserverGlue: ResourceObserver, CustomDebugStringConvertible
    {
    weak var objcObserver: _objc_ResourceObserver?
    
    init(objcObserver: _objc_ResourceObserver)
        { self.objcObserver = objcObserver }

    func resourceChanged(resource: Resource, event: ResourceEvent)
        { objcObserver?.resourceChanged(resource, event: event.rawValue) }
    
    func resourceRequestProgress(resource: Resource)
        { objcObserver?.resourceRequestProgress?(resource) }
    
    func stoppedObservingResource(resource: Resource)
        { objcObserver?.stoppedObservingResource?(resource) }
    
    var debugDescription: String
        {
        if objcObserver != nil
            { return debugStr(objcObserver) }
        else
            { return "_objc_ResourceObserverGlue<deallocated delegate>" }
        }
    }

public extension Resource
    {
    @objc(addObserver:)
    public func _objc_addObserver(observerAndOwner: protocol<_objc_ResourceObserver, AnyObject>) -> Self
        { return addObserver(_objc_ResourceObserverGlue(objcObserver: observerAndOwner), owner: observerAndOwner) }

    @objc(addObserver:owner:)
    public func _objc_addObserver(objcObserver: _objc_ResourceObserver, owner: AnyObject) -> Self
        { return addObserver(_objc_ResourceObserverGlue(objcObserver: objcObserver), owner: owner) }
    }

extension ResourceStatusOverlay: _objc_ResourceObserver
    {
    public func resourceChanged(resource: Resource, event: String)
        { self.resourceChanged(resource, event: ResourceEvent(rawValue: event)!) }
    }

