//
//  Quick+Siesta.swift
//  Siesta
//
//  Created by Paul on 2015/6/20.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Quick

public func specVar<T>(builder: () -> T) -> () -> T
    {
    var value: T?
    afterEach { value = nil }
    return
        {
        let builtValue = value ?? builder()
        value = builtValue
        return builtValue
        }
    }

func simulateMemoryWarning()
    {
    NSNotificationCenter
        .defaultCenter()
        .postNotificationName(
            UIApplicationDidReceiveMemoryWarningNotification,
            object: nil)
    }
