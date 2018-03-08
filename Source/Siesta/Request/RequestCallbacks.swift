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

internal final class ConcreteRequest: Request, RequestCompletionHandler, CustomDebugStringConvertible
    {
    private let delegate: RequestDelegate
    private var responseCallbacks = CallbackGroup<ResponseInfo>()
    private var progressTracker = ProgressTracker()
    internal private(set) var isStarted = false, isCancelled = false

    init(delegate: RequestDelegate)
        {
        self.delegate = delegate
        }

    // Standard behavior

    @discardableResult
    final func start() -> Request
        {
        DispatchQueue.mainThreadPrecondition()

        guard !isStarted else
            {
            debugLog(.networkDetails, [delegate.requestDescription, "already started"])
            return self
            }

        guard !isCancelled else
            {
            debugLog(.network, [delegate.requestDescription, "will not start because it was already cancelled"])
            return self
            }

        isStarted = true
        debugLog(.network, [delegate.requestDescription])

        delegate.startUnderlyingOperation(completionHandler: self)

        progressTracker.start(
            progressProvider: { [delegate] in delegate.progress },
            reportingInterval: delegate.progressReportingInterval)

        return self
        }

    final func cancel()
        {
        DispatchQueue.mainThreadPrecondition()

        guard !isCompleted else
            {
            debugLog(.network, ["cancel() called but request already completed:", delegate.requestDescription])
            return
            }

        debugLog(.network, ["Cancelled", delegate.requestDescription])

        delegate.cancelUnderlyingOperation()

        // Prevent start() from have having any effect if it hasn't been called yet
        isCancelled = true

        broadcastResponse(.cancellation)
        }

    func onProgress(_ callback: @escaping (Double) -> Void) -> Request
        {
        progressTracker.callbacks.addCallback(callback)
        return self;
        }

    func repeated() -> Request
        {
        return delegate.repeatedRequest()
        }

    final func onCompletion(_ callback: @escaping (ResponseInfo) -> Void) -> Request
        {
        responseCallbacks.addCallback(callback)
        return self
        }

    var progress: Double
        { return progressTracker.progress }

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
                "WARNING: Received response for request that was already completed:", delegate.requestDescription,
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
                "Received response, but request was already cancelled:", delegate.requestDescription,
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

        progressTracker.complete()

        responseCallbacks.notifyOfCompletion(newInfo)
        }

    // MARK: Debug

    final var debugDescription: String
        {
        return "Request:"
            + String(UInt(bitPattern: ObjectIdentifier(self)), radix: 16)
            + "("
            + delegate.requestDescription
            + ")"
        }
    }

protocol RequestDelegate
    {
    func startUnderlyingOperation(completionHandler: RequestCompletionHandler)

    func cancelUnderlyingOperation()

    func repeatedRequest() -> Request

    var progress: Double { get }

    var progressReportingInterval: Double { get }

    var requestDescription: String { get }
    }

protocol RequestCompletionHandler
    {
    func shouldIgnoreResponse(_ newResponse: Response) -> Bool

    func broadcastResponse(_ newInfo: ResponseInfo)

    var isCancelled: Bool { get }
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
