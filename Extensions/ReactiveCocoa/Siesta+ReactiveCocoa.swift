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

public struct ResourceState<T>
    {
    public var content: T?
    public var error: RequestError?
    public var isLoading, isRequesting: Bool
    }

public extension Resource
    {
    public func snapshot<T>()
        -> ResourceState<T>
        {
        let content: T? = latestData?.typedContent()
        let contentTypeError: RequestError? =
            (latestData != nil && content == nil)
                ? RequestError(
                    userMessage: "The server return an unexpected response type",
                    cause: RequestError.Cause.WrongContentType())
                : nil

        return ResourceState<T>(
            content: content,
            error: latestError ?? contentTypeError,
            isLoading: isLoading,
            isRequesting: isRequesting)

        }
    }

extension RequestError.Cause
    {
    public struct WrongContentType: RequestError { }
    }

public struct ReactiveObserver<T>
    {
    public let signal: Signal<ResourceState<T>, NoError>
    private let observer: Observer<ResourceState<T>, NoError>

    public init()
        {
        (signal, observer) = Signal<ResourceState<T>, NoError>.pipe()
        }
    }

extension ReactiveObserver: ResourceObserver
    {
    public func resourceChanged(_ resource: Resource, event: ResourceEvent)
        {
        observer.sendNext(resource.snapshot())
        }
    }

public extension Resource
    {
    public func rac_signal<T>(
            _ owner: AnyObject)
        -> Signal<ResourceState<T>, NoError>
        {
        let reactiveObserver = ReactiveObserver<T>()
        self.addObserver(reactiveObserver, owner: owner)
        return reactiveObserver.signal
        }
    }

public extension Request
    {
    public func rac_signal()
        -> SignalProducer<Entity<Any>, RequestError>
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

    public func rac_progress()
        -> Signal<Double, NoError>
        {
        return Signal
            {
            [weak self] observer in
            self?
                .onProgress
                    {
                    progress in
                    observer.sendNext(progress)
                    if progress == 1 { observer.sendCompleted() }
                    }
            return nil
            }
        }
    }

