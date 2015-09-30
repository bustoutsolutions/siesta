//
//  Progress.swift
//  Siesta
//
//  Created by Paul on 2015/9/28.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Foundation

protocol Progress
    {
    var fractionDone: Double { get }
    var rawFractionDone: Double { get }
    }

extension Progress
    {
    final var fractionDone: Double
        { return max(0, min(1, rawFractionDone)) }
    }

class TaskProgress: Progress
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

struct CompoundProgress: Progress
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

struct MonotonicProgress: Progress
    {
    var child: Progress
    private var gamma: Double = 1
    
    init(_ child: Progress)
        { self.child = child }
    
    var rawFractionDone: Double
        { return pow(child.fractionDone, gamma) }
    
    mutating func holdConstant(@noescape closure: Void -> Void)
        {
        let before = fractionDone
        closure()
        if before != 0
            { gamma = log(before) / log(child.fractionDone) }
        }
    }
