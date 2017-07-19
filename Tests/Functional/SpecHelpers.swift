//
//  SpecHelpers.swift
//  Siesta
//
//  Created by Paul on 2015/6/20.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Quick
import Nimble
import Nocilla
@testable import Siesta

public func specVar<T>(_ builder: @escaping () -> T) -> () -> T
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
    NotificationCenter.default
        .post(
            name: Siesta.MemoryWarningNotification,
            object: nil)
    }

func beIdentialObjects<T>(_ expectedArray: [T]) -> Predicate<[T]>
    {
    func makeIdent(_ x: T) -> ObjectIdentifier
        {
        return ObjectIdentifier(x as AnyObject)
        }

    return Predicate
        {
        inputs in
        let actualArray = try inputs.evaluate()!
        return PredicateResult(
            bool: expectedArray.map(makeIdent) == actualArray.map(makeIdent),
            message: ExpectationMessage.fail(
                "expected specific objects \(stringify(expectedArray)) but got \(stringify(actualArray))"))
        }
    }
