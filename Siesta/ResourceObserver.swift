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

