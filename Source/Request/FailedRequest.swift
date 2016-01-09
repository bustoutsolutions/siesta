//
//  FailedRequest.swift
//  Siesta
//
//  Created by Paul on 2015/12/15.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

/// For requests that failed before they even made it to the network layer
internal final class FailedRequest: RequestWithDefaultCallbacks
    {
    private let error: Error

    var isCompleted: Bool { return true }
    var progress: Double { return 1 }

    init(_ error: Error)
        { self.error = error }

    func addResponseCallback(callback: ResponseCallback)
        {
        // FailedRequest is immutable and thus threadsafe. However, this call would not be safe if this were a
        // NetworkRequest, and callers can’t assume they’re getting a FailedRequest, so we validate main thread anyway.

        dispatch_assert_main_queue()

        // Callback should not be called synchronously

        dispatch_async(dispatch_get_main_queue())
            { callback((.Failure(self.error), isNew: true)) }
        }

    func onProgress(callback: Double -> Void) -> Self
        {
        dispatch_assert_main_queue()

        dispatch_async(dispatch_get_main_queue())
            { callback(1) }

        return self
        }

    func cancel()
        { dispatch_assert_main_queue() }
    }
