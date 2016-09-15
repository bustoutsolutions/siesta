//
//  GCD+Siesta.swift
//  Siesta
//
//  Created by Paul on 2015/8/27.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

extension DispatchQueue
    {
    // props to http://stackoverflow.com/a/24318861/239816
    internal func asyncAfter(delay: TimeInterval, closure: @escaping (Void) -> Void)
        {
        asyncAfter(
            deadline: DispatchTime.now() + delay,
            execute: closure)
        }
    }

extension DispatchQueue
    {
    internal static func mainThreadPrecondition(caller: String = #function)
        {
        precondition(
            Thread.isMainThread,
            "Illegal attempt to use Siesta method \"\(caller)\" from a background thread. " +
            "Except in specific situations, you must call Siesta APIs from the main thread. " +
            "See http://bustoutsolutions.github.io/siesta/guide/threading/")
        }
    }
