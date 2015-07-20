//
//  Quick+Siesta.swift
//  Siesta
//
//  Created by Paul on 2015/6/20.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Quick
import Nimble

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

func beIdentialObjects<T:AnyObject>(expectedArray: [T]) -> MatcherFunc<[T]>
    {
    return MatcherFunc
        { inputs, failureMessage in
        
        let actualArray = inputs.evaluate()!
        failureMessage.stringValue =
            "expected \(expectedArray)"
            + " but got \(actualArray)"
        
        return expectedArray.map { ObjectIdentifier($0).uintValue }
            ==   actualArray.map { ObjectIdentifier($0).uintValue }
        }
    }
