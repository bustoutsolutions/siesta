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

public struct ResourceState
    {
    public var data: Entity?
    public var error: Error?
    public var isLoading, isRequesting: Bool
    }

public extension Resource
    {
    var state: ResourceState
        {
        return ResourceState(
            data: latestData,
            error: latestError,
            isLoading: isLoading,
            isRequesting: isRequesting)

        }
    }

public struct ReactiveObserver
    {
    public let signal: Signal<ResourceState, NoError>
    private let observer: Observer<ResourceState, NoError>

    public init()
        {
        (signal, observer) = Signal<ResourceState, NoError>.pipe()
        }
    }

extension ReactiveObserver: ResourceObserver
    {
    public func resourceChanged(resource: Resource, event: ResourceEvent)
        {
        observer.sendNext(resource.state)
        }
    }

public extension Resource
    {
    public func rac_signal(
        owner: AnyObject)
            -> Signal<ResourceState, NoError>
        {
        let reactiveObserver = ReactiveObserver()
        self.addObserver(reactiveObserver, owner: owner)
        return reactiveObserver.signal
        }
    }

public extension Request
    {
    public func rac_signal()
        -> SignalProducer<Entity, Error>
        {
        return SignalProducer
            {
            [weak self] observer, disposable in
            self?
                .onSuccess
                    {
                    entity in
                    observer.sendNext(entity)
                    observer.sendCompleted()
                    }
                .onFailure
                    {
                    error in
                    observer.sendFailed(error)
                    }
            disposable.addDisposable
                {
                [weak self] in
                self?.cancel()
                }
            }
        }
    }

