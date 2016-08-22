//
//  Progress.swift
//  Siesta
//
//  Created by Paul on 2015/9/28.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation


internal struct RequestProgressComputation: Progress
    {
    private var uploadProgress, downloadProgress: TaskProgress
    private var connectLatency, responseLatency: WaitingProgress
    private var overallProgress: MonotonicProgress

    init(isGet: Bool)
        {
        uploadProgress   = TaskProgress(estimatedTotal: 8192)   // bytes
        downloadProgress = TaskProgress(estimatedTotal: 65536)
        connectLatency  = WaitingProgress(estimatedTotal: 2.5)  // seconds to reach 75%
        responseLatency = WaitingProgress(estimatedTotal: 1.2)

        overallProgress =
            MonotonicProgress(
                CompoundProgress(components:
                    (connectLatency,   weight: 0.3),
                    (uploadProgress,   weight: isGet ? 0 : 1),
                    (responseLatency,  weight: 0.3),
                    (downloadProgress, weight: isGet ? 1 : 0.1)))
        }

    mutating func update(from metrics: RequestTransferMetrics)
        {
        updateByteCounts(from: metrics)
        updateLatency(from: metrics)
        }

    mutating func updateByteCounts(from metrics: RequestTransferMetrics)
        {
        func optionalTotal(_ n: Int64?) -> Double?
            {
            if let n = n, n > 0
                { return Double(n) }
            else
                { return nil }
            }

        overallProgress.holdConstant
            {
            uploadProgress.actualTotal   = optionalTotal(metrics.requestBytesTotal)
            downloadProgress.actualTotal = optionalTotal(metrics.responseBytesTotal)
            }

        uploadProgress.completed   = Double(metrics.requestBytesSent)
        downloadProgress.completed = Double(metrics.responseBytesReceived)
        }

    mutating func updateLatency(from metrics: RequestTransferMetrics)
        {
        let requestStarted = metrics.requestBytesSent > 0,
            responseStarted = metrics.responseBytesReceived > 0,
            requestSent = requestStarted && metrics.requestBytesSent == metrics.requestBytesTotal

        if requestStarted || responseStarted
            {
            overallProgress.holdConstant
                { connectLatency.complete() }
            }
        else
            { connectLatency.tick() }

        if responseStarted
            {
            overallProgress.holdConstant
                { responseLatency.complete() }
            }
        else if requestSent
            { responseLatency.tick() }
        }

    mutating func complete()
        { overallProgress.child = TaskProgress.completed }

    var rawFractionDone: Double
        {
        return overallProgress.fractionDone
        }
    }

// MARK: Generic progress computation

// The code from here to the bottom is a good candidate for open-sourcing as a separate project.

/// Generic task that goes from 0 to 1.
internal protocol Progress
    {
    var rawFractionDone: Double { get }
    }

extension Progress
    {
    final var fractionDone: Double
        {
        let raw = rawFractionDone
        return raw.isNaN ? raw : max(0, min(1, raw))
        }
    }

/// A task that has a known amount of homogenous work completed (e.g. bytes transferred).
private class TaskProgress: Progress
    {
    /// The amount of work done, in arbitrary units.
    var completed: Double

    /// The actual amount of work to do, if known. In same units as `completed`.
    var actualTotal: Double?

    /// The 75% point for an asymptotic curve. In same units as `completed`.
    /// Ignored if actualTotal is present.
    var estimatedTotal: Double

    init(completed: Double = 0, estimatedTotal: Double)
        {
        self.completed = completed
        self.estimatedTotal = estimatedTotal
        }

    init(completed: Double = 0, actualTotal: Double)
        {
        self.completed = completed
        self.actualTotal = actualTotal
        self.estimatedTotal = actualTotal
        }

    var rawFractionDone: Double
        {
        if let actualTotal = actualTotal
            { return completed / actualTotal }
        else
            { return 1 - pow(2, -2 * completed / estimatedTotal) }
        }

    static var completed: TaskProgress
        { return TaskProgress(completed: 1, actualTotal: 1) }

    static var unknown: TaskProgress
        { return TaskProgress(completed: 0, estimatedTotal: Double.nan) }
    }

/// Several individual progress measurements combined into one.
private struct CompoundProgress: Progress
    {
    var components: [Component]

    init(components: Component...)
        { self.components = components }

    var rawFractionDone: Double
        {
        var total = 0.0, totalWeight = 0.0
        for component in components
            {
            total += component.progress.fractionDone * component.weight
            totalWeight += component.weight
            }

        return total / totalWeight
        }

    typealias Component = (progress: Progress, weight: Double)
    }

/// Wraps a progress computation, holding the result constant during potentially unstable operations such as
/// changing the amount of estimated work remaining.
private struct MonotonicProgress: Progress
    {
    var child: Progress

    private var adjustment: Double = 1

    init(_ child: Progress)
        { self.child = child }

    var rawFractionDone: Double
        { return (child.fractionDone - 1) * adjustment + 1 }

    mutating func holdConstant(closure: (Void) -> Void)
        {
        let before = fractionDone
        closure()
        let afterRaw = child.fractionDone
        if afterRaw != 1
            { adjustment = (before - 1) / (afterRaw - 1) }
        }
    }

/// Progress spent waiting for something that will take an unknown amount of time.
private class WaitingProgress: Progress
    {
    private var startTime: TimeInterval?
    private var progress: TaskProgress

    init(estimatedTotal: Double)
        { progress = TaskProgress(estimatedTotal: estimatedTotal) }

    var rawFractionDone: Double
        { return progress.rawFractionDone }

    func tick()
        {
        let now = Siesta.now()
        if let startTime = startTime
            { progress.completed = now - startTime }
        else
            { startTime = now }
        }

    func complete()
        {
        progress.completed = Double.infinity
        }
    }
