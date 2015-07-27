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

func beIdentialObjects<T>(expectedArray: [T]) -> NonNilMatcherFunc<[T]>
    {
    func makeIdent(x: T) -> ObjectIdentifier
        {
        if let obj = x as? AnyObject
            { return ObjectIdentifier(obj) }
        else
            { return ObjectIdentifier(NSObject()) }   // ident not equal to anything else, so fails non-objects in Array
        }
    
    return NonNilMatcherFunc
        { inputs, failureMessage in

        let actualArray = try! inputs.evaluate()!
        failureMessage.stringValue =
            "expected \(expectedArray)"
            + " but got \(actualArray)"
        
        return expectedArray.map(makeIdent)
            ==   actualArray.map(makeIdent)
        }
    }
