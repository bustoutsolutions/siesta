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

internal class AbstractRequest: Request, CustomStringConvertible, CustomDebugStringConvertible
    {
    private let requestDescription: String
    private var responseCallbacks = CallbackGroup<ResponseInfo>()
    internal private(set) var isStarted = false, isCancelled = false

    init(requestDescription: String)
        {
        self.requestDescription = requestDescription
        }

    // Standard behavior

    final func start() -> Request
        {
        DispatchQueue.mainThreadPrecondition()

        guard !isStarted else
            {
            debugLog(.networkDetails, [requestDescription, "already started"])
            return self
            }

        guard !isCancelled else
            {
            debugLog(.network, [requestDescription, "will not start because it was already cancelled"])
            return self
            }

        isStarted = true
        debugLog(.network, [requestDescription])

        startUnderlyingOperation()

        return self
        }

    final func cancel()
        {
        DispatchQueue.mainThreadPrecondition()

        guard !isCompleted else
            {
            debugLog(.network, ["cancel() called but request already completed:", requestDescription])
            return
            }

        debugLog(.network, ["Cancelled", requestDescription])

        cancelUnderlyingOperation()

        // Prevent start() from have having any effect if it hasn't been called yet
        isCancelled = true

        broadcastResponse(.cancellation)
        }

    final func onCompletion(_ callback: @escaping (ResponseInfo) -> Void) -> Request
        {
        responseCallbacks.addCallback(callback)
        return self
        }

    final var isCompleted: Bool
        {
        DispatchQueue.mainThreadPrecondition()

        return responseCallbacks.completedValue != nil
        }

    final func shouldIgnoreResponse(_ newResponse: Response) -> Bool
        {
        guard let existingResponse = responseCallbacks.completedValue?.response else
            { return false }

        // We already received a response; don't broadcast another one.

        if !existingResponse.isCancellation
            {
            debugLog(.network,
                [
                "WARNING: Received response for request that was already completed:", requestDescription,
                "This may indicate a bug in the NetworkingProvider you are using, or in Siesta.",
                "Please file a bug report: https://github.com/bustoutsolutions/siesta/issues/new",
                "\n    Previously received:", existingResponse,
                "\n    New response:", newResponse
                ])
            }
        else if !newResponse.isCancellation
            {
            // Sometimes the network layer sends a cancellation error. That’s not of interest if we already knew
            // we were cancelled. If we received any other response after cancellation, log that we ignored it.

            debugLog(.networkDetails,
                [
                "Received response, but request was already cancelled:", requestDescription,
                "\n    New response:", newResponse
                ])
            }

        return true
        }

    final func broadcastResponse(_ newInfo: ResponseInfo)
        {
        DispatchQueue.mainThreadPrecondition()

        if shouldIgnoreResponse(newInfo.response)
            { return }

        willNotifyCompletionCallbacks()

        responseCallbacks.notifyOfCompletion(newInfo)
        }

    // Subtype-specific behavior

    func startUnderlyingOperation()
        {
        fatalError("subclasses must implement")
        }

    func cancelUnderlyingOperation()
        {
        fatalError("subclasses must implement")
        }

    func willNotifyCompletionCallbacks()
        { }

    func repeated() -> Request
        {
        fatalError("subclasses must implement")
        }

    // Dummy implementaiton of progress; subclasses can override if they have useful progress info

    var progress: Double
        { return isCompleted ? 1 : 0 }

    func onProgress(_ callback: @escaping (Double) -> Void) -> Request
        { return self }

    // MARK: Debug

    final var description: String
        {
        return requestDescription
        }

    final var debugDescription: String
        {
        return "Request:"
            + String(UInt(bitPattern: ObjectIdentifier(self)), radix: 16)
            + "("
            + requestDescription
            + ")"
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
