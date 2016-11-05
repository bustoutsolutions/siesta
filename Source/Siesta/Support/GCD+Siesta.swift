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
    internal static func mainThreadPrecondition(caller: String = #function)
        {
        precondition(
            Thread.isMainThread,
            "Illegal attempt to use Siesta method \"\(caller)\" from a background thread. " +
            "Except in specific situations, you must call Siesta APIs from the main thread. " +
            "See https://bustoutsolutions.github.io/siesta/guide/threading/")
        }
    }
