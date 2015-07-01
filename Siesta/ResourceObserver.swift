//
//  ResourceObserver.swift
//  Siesta
//
//  Created by Paul on 2015/6/29.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

public protocol ResourceObserver
    {
    }

extension ResourceObserver
    {
    func resourceChanged(resource: Resource, event: ResourceEvent) { }
    
    func resourceRequestProgress(resource: Resource) { }
    }

public typealias ResourceObserverClosure = (resource: Resource, event: ResourceEvent) -> ()
public typealias ResourceProgressObserverClosure = (resource: Resource) -> ()

public enum ResourceEvent
    {
    case OBSERVER_ADDED  // Sent only to the newly attached observer, not all observers
    case REQUESTED
    case REQUEST_SUCCEEDED
    case REQUEST_FAILED
    
    var signalsStateChange: Bool
        {
        switch(self)
            {
            case OBSERVER_ADDED, REQUESTED:
                return false
            case REQUEST_SUCCEEDED, REQUEST_FAILED:
                return true
            }
        }
    }
