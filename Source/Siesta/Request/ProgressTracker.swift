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
    var callbacks = CallbackGroup<Double>()

    private var progressProvider: () -> Double
    private var lastProgressBroadcast: Double?
    private var progressUpdateTimer: Timer?

    init()
        {
        progressProvider = { 0 }
        }

    func start(progressProvider: @escaping () -> Double, reportingInterval: TimeInterval)
        {
        precondition(progressUpdateTimer == nil, "already started")

        self.progressProvider = progressProvider

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
        let progress = progressProvider()

        if lastProgressBroadcast != progress
            {
            lastProgressBroadcast = progress
            callbacks.notify(progress)
            }
        }

    var progress: Double
        { return lastProgressBroadcast ?? 0 }

    func complete()
        {
        progressUpdateTimer?.invalidate()
        lastProgressBroadcast = 1
        callbacks.notifyOfCompletion(1)
        }
    }
