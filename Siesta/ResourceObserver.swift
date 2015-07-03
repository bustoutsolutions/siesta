//
//  ResourceObserver.swift
//  Siesta
//
//  Created by Paul on 2015/6/29.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

public protocol ResourceObserver
    {
    func resourceChanged(resource: Resource, event: ResourceEvent)
    }

extension ResourceObserver
    {
    func resourceRequestProgress(resource: Resource) { }
    }

public typealias ResourceObserverClosure = (resource: Resource, event: ResourceEvent) -> ()
public typealias ResourceProgressObserverClosure = (resource: Resource) -> ()

public enum ResourceEvent
    {
    case OBSERVER_ADDED  // Sent only to the newly attached observer, not all observers
    case REQUESTED
    case REQUEST_CANCELLED
    case NEW_DATA_RESPONSE
    case NOT_MODIFIED_RESPONSE
    case ERROR_RESPONSE
    
    var signalsStateChange: Bool
        {
        switch(self)
            {
            case OBSERVER_ADDED, REQUESTED, NOT_MODIFIED_RESPONSE, REQUEST_CANCELLED:
                return false
            
            case NEW_DATA_RESPONSE, ERROR_RESPONSE:
                return false
            }
        }
    }

