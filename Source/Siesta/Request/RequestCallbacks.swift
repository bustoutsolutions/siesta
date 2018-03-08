//
//  RequestCallbacks.swift
//  Siesta
//
//  Created by Paul on 2015/12/15.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

/// Wraps all the `Request` hooks as `ResponseCallback`s and funnels them through `onCompletion(_:)`.
extension Request
    {
    func onSuccess(_ callback: @escaping (Entity<Any>) -> Void) -> Request
        {
        return onCompletion
            {
            if case .success(let entity) = $0.response
                { callback(entity) }
            }
        }

    func onNewData(_ callback: @escaping (Entity<Any>) -> Void) -> Request
        {
        return onCompletion
            {
            if $0.isNew, case .success(let entity) = $0.response
                { callback(entity) }
            }
        }

    func onNotModified(_ callback: @escaping () -> Void) -> Request
        {
        return onCompletion
            {
            if !$0.isNew, case .success = $0.response
                { callback() }
            }
        }

    func onFailure(_ callback: @escaping (RequestError) -> Void) -> Request
        {
        return onCompletion
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

        // We need to let this mutating method finish before calling the callbacks. Some of them inspect
        // completeValue (via isCompleted), which causes a simultaneous access error at runtime.
        // See https://github.com/apple/swift-evolution/blob/master/proposals/0176-enforce-exclusive-access-to-memory.md

        let snapshot = self
        DispatchQueue.main.async
            { snapshot.notify(arguments) }

        // Fly, little handlers, be free! Now that we have a result, future onFoo() calls will invoke the callback.
        callbacks = []
        }
    }
