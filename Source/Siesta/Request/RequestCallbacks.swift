//
//  RequestCallbacks.swift
//  Siesta
//
//  Created by Paul on 2015/12/15.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

internal typealias ResponseCallback = ResponseInfo -> Void

internal protocol RequestWithDefaultCallbacks: Request
    {
    func addResponseCallback(callback: ResponseCallback) -> Self
    }

/// Wraps all the `Request` hooks as `ResponseCallback`s and funnels them through `addResponseCallback(_:)`.
extension RequestWithDefaultCallbacks
    {
    func onCompletion(callback: (ResponseInfo) -> Void) -> Self
        {
        return addResponseCallback(callback)
        }

    func onSuccess(callback: Entity -> Void) -> Self
        {
        return addResponseCallback
            {
            if case .Success(let entity) = $0.response
                { callback(entity) }
            }
        }

    func onNewData(callback: Entity -> Void) -> Self
        {
        return addResponseCallback
            {
            if case .Success(let entity) = $0.response where $0.isNew
                { callback(entity) }
            }
        }

    func onNotModified(callback: Void -> Void) -> Self
        {
        return addResponseCallback
            {
            if case .Success = $0.response where !$0.isNew
                { callback() }
            }
        }

    func onFailure(callback: Error -> Void) -> Self
        {
        return addResponseCallback
            {
            if case .Failure(let error) = $0.response
                { callback(error) }
            }
        }
    }

/// Unified handling for both `ResponseCallback` and `progress()` callbacks.
internal struct CallbackGroup<CallbackArguments>
    {
    private(set) var completedValue: CallbackArguments?
    private var callbacks: [CallbackArguments -> Void] = []

    mutating func addCallback(callback: CallbackArguments -> Void)
        {
        dispatch_assert_main_queue()

        if let completedValue = completedValue
            {
            // Request already completed. Callback can run immediately, but queue it on the main thread so that the
            // caller can finish their business first.

            dispatch_async(dispatch_get_main_queue())
                { callback(completedValue) }
            }
        else
            {
            callbacks.append(callback)
            }
        }

    func notify(arguments: CallbackArguments)
        {
        dispatch_assert_main_queue()

        // Note that callbacks will be [] after notifyOfCompletion() called, so this becomes a noop.

        for callback in callbacks
            { callback(arguments) }
        }

    mutating func notifyOfCompletion(arguments: CallbackArguments)
        {
        precondition(completedValue == nil, "notifyOfCompletion() already called")

        // Remember outcome in case more handlers are added after request is already completed
        completedValue = arguments

        notify(arguments)
        callbacks = []  // Fly, little handlers, be free!
        }
    }

