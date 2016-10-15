//
//  RequestCallbacks.swift
//  Siesta
//
//  Created by Paul on 2015/12/15.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

internal typealias ResponseCallback = (ResponseInfo) -> Void

internal protocol RequestWithDefaultCallbacks: Request
    {
    func addResponseCallback(_ callback: @escaping ResponseCallback) -> Self
    }

/// Wraps all the `Request` hooks as `ResponseCallback`s and funnels them through `addResponseCallback(_:)`.
extension RequestWithDefaultCallbacks
    {
    func onCompletion(_ callback: @escaping (ResponseInfo) -> Void) -> Self
        {
        return addResponseCallback(callback)
        }

    func onSuccess(_ callback: @escaping (Entity<Any>) -> Void) -> Self
        {
        return addResponseCallback
            {
            if case .success(let entity) = $0.response
                { callback(entity) }
            }
        }

    func onNewData(_ callback: @escaping (Entity<Any>) -> Void) -> Self
        {
        return addResponseCallback
            {
            if $0.isNew, case .success(let entity) = $0.response
                { callback(entity) }
            }
        }

    func onNotModified(_ callback: @escaping (Void) -> Void) -> Self
        {
        return addResponseCallback
            {
            if !$0.isNew, case .success = $0.response
                { callback() }
            }
        }

    func onFailure(_ callback: @escaping (RequestError) -> Void) -> Self
        {
        return addResponseCallback
            {
            if case .failure(let error) = $0.response
                { callback(error) }
            }
        }
    }

/// Unified handling for both `ResponseCallback` and `progress()` callbacks.
internal struct CallbackGroup<CallbackArguments>
    {
    private(set) var completedValue: CallbackArguments?
    private var callbacks: [(CallbackArguments) -> Void] = []

    mutating func addCallback(_ callback: @escaping (CallbackArguments) -> Void)
        {
        DispatchQueue.mainThreadPrecondition()

        if let completedValue = completedValue
            {
            // Request already completed. Callback can run immediately, but queue it on the main thread so that the
            // caller can finish their business first.

            DispatchQueue.main.async
                { callback(completedValue) }
            }
        else
            {
            callbacks.append(callback)
            }
        }

    func notify(_ arguments: CallbackArguments)
        {
        DispatchQueue.mainThreadPrecondition()

        // Note that callbacks will be [] after notifyOfCompletion() called, so this becomes a noop.

        for callback in callbacks
            { callback(arguments) }
        }

    mutating func notifyOfCompletion(_ arguments: CallbackArguments)
        {
        precondition(completedValue == nil, "notifyOfCompletion() already called")

        // Remember outcome in case more handlers are added after request is already completed
        completedValue = arguments

        notify(arguments)
        callbacks = []  // Fly, little handlers, be free!
        }
    }
