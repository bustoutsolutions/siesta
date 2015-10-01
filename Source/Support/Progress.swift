//
//  Progress.swift
//  Siesta
//
//  Created by Paul on 2015/9/28.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Foundation

internal protocol Progress
    {
    var fractionDone: Double { get }
    var rawFractionDone: Double { get }
    }

extension Progress
    {
    final var fractionDone: Double
        { return max(0, min(1, rawFractionDone)) }
    }

internal class TaskProgress: Progress
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
        { return TaskProgress(completed: 0, estimatedTotal: Double.NaN) }
    }

internal struct CompoundProgress: Progress
    {
    var components: [Component]
    
    init(components: Component...)
        { self.components = components }
    
    var rawFractionDone: Double
        {
        var total = 0.0, totalWeight = 0.0
        for component in components
            {
            total += component.progress.fractionDone * component.weight;
            totalWeight += component.weight;
            }

        return total / totalWeight
        }
    
    typealias Component = (progress: Progress, weight: Double)
    }

internal struct MonotonicProgress: Progress
    {
    var child: Progress
    
    private var adjustment: Double = 1
    
    init(_ child: Progress)
        { self.child = child }
    
    var rawFractionDone: Double
        { return (child.fractionDone - 1) * adjustment + 1 }
    
    mutating func holdConstant(@noescape closure: Void -> Void)
        {
        let before = fractionDone
        closure()
        let afterRaw = child.fractionDone
        if afterRaw != 1
            { adjustment = (before - 1) / (afterRaw - 1) }
        }
    }

internal class WaitingProgress: Progress
    {
    private var startTime: NSTimeInterval?
    private var progress: TaskProgress
    
    init(estimatedTotal: Double)
        { progress = TaskProgress(estimatedTotal: estimatedTotal) }
    
    var rawFractionDone: Double
        { return progress.rawFractionDone }
    
    func tick()
        {
        let now = NSDate.timeIntervalSinceReferenceDate()
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

