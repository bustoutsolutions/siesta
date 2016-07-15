//
//  Siesta+ReactiveCocoa.swift
//  Siesta
//
//  Created by Ahmet Karalar on 15/07/16.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation
import Siesta
import ReactiveCocoa
import Result

public struct ResourceState {
    public var data: Entity?
    public var error: Error?
    public var isLoading, isRequesting: Bool
}

public extension Resource {
    var state: ResourceState {
        return ResourceState(
            data: latestData,
            error: latestError,
            isLoading: isLoading,
            isRequesting: isRequesting)
    }
}

public extension Resource {
    
    public func rac_signal(
        owner: AnyObject)
        -> Signal<ResourceState, NoError>
    {
        let reactiveObserver = ReactiveObserver()
        self.addObserver(reactiveObserver, owner: owner)
        return reactiveObserver.signal
    }
}

public struct ReactiveObserver {
    public let signal: ReactiveCocoa.Signal<ResourceState, NoError>
    private let observer: ReactiveCocoa.Observer<ResourceState, NoError>
    
    public init() {
        (signal, observer) = Signal<ResourceState, NoError>.pipe()
    }
}

extension ReactiveObserver: ResourceObserver {
    public func resourceChanged(resource: Resource, event: ResourceEvent) {
        observer.sendNext(resource.state)
    }
}
