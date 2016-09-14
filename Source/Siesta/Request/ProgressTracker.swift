//
//  ProgressTracker.swift
//  Siesta
//
//  Created by Paul on 2015/12/15.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

internal class ProgressTracker
    {
    var progress: Double
        { return progressComputation.fractionDone }
    var callbacks = CallbackGroup<Double>()

    private var networking: RequestNetworking?

    private var lastProgressBroadcast: Double?
    private var progressComputation: RequestProgressComputation
    private var progressUpdateTimer: Timer?

    init(isGet: Bool)
        {
        progressComputation = RequestProgressComputation(isGet: isGet)
        }

    func start(_ networking: RequestNetworking, reportingInterval: TimeInterval)
        {
        precondition(self.networking == nil, "already started")

        self.networking = networking

        progressUpdateTimer =
            CFRunLoopTimerCreateWithHandler(
                    kCFAllocatorDefault,
                    CFAbsoluteTimeGetCurrent(),
                    reportingInterval, 0, 0)
                { [weak self] _ in self?.updateProgress() }
        CFRunLoopAddTimer(CFRunLoopGetCurrent(), progressUpdateTimer, CFRunLoopMode.commonModes)
        }

    deinit
        {
        progressUpdateTimer?.invalidate()
        }

    private func updateProgress()
        {
        guard let networking = networking else
            { return }

        progressComputation.update(from: networking.transferMetrics)

        let progress = self.progress
        if lastProgressBroadcast != progress
            {
            lastProgressBroadcast = progress
            callbacks.notify(progress)
            }
        }

    func complete()
        {
        progressUpdateTimer?.invalidate()
        progressComputation.complete()
        callbacks.notifyOfCompletion(1)
        }
    }
