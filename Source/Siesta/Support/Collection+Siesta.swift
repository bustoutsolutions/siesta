//
//  Collection+Siesta.swift
//  Siesta
//
//  Created by Paul on 2015/7/19.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

internal extension Collection
    {
    func bipartition(
            with predicate: (Self.Iterator.Element) -> Bool)
        -> (included: [Self.Iterator.Element], excluded: [Self.Iterator.Element])
        {
        var included: [Self.Iterator.Element] = []
        var excluded: [Self.Iterator.Element] = []

        for elem in self
            {
            if predicate(elem)
                { included.append(elem) }
            else
                { excluded.append(elem) }
            }

        return (included: included, excluded: excluded)
        }

    func any(match predicate: (Iterator.Element) -> Bool) -> Bool
        {
        for elem in self
            where predicate(elem)
                { return true }
        return false
        }

    func all(match predicate: (Iterator.Element) -> Bool) -> Bool
        {
        return !any { !predicate($0) }
        }
    }

internal extension Array
    {
    mutating func remove(matching predicate: (Iterator.Element) -> Bool)
        {
        var dst = startIndex
        for src in indices
            {
            let elem = self[src]
            if !predicate(elem)
                {
                self[dst] = elem
                dst = dst.advanced(by: 1)
                }
            }
        removeSubrange(dst ..< endIndex)
        }
    }

internal extension Dictionary
    {
    static func fromArray<K,V>(_ arrayOfTuples: [(K,V)]) -> [K:V]
        {
        var dict = Dictionary<K,V>(minimumCapacity: arrayOfTuples.count)
        for (k,v) in arrayOfTuples
            { dict[k] = v }
        return dict
        }

    func mapDict<MappedKey,MappedValue>(transform: (Key,Value) -> (MappedKey,MappedValue))
        -> [MappedKey:MappedValue]
        {
        return Dictionary.fromArray(map(transform))
        }

    func flatMapDict<MappedKey,MappedValue>(transform: (Key,Value) -> (MappedKey?,MappedValue?))
        -> [MappedKey:MappedValue]
        {
        return Dictionary.fromArray(
            flatMap
                {
                let (k,v) = transform($0, $1)
                if let k = k, let v = v
                    { return (k,v) }
                else
                    { return nil }
                }
            )
        }

    mutating func cacheValue(forKey key: Key, ifNone newValue: () -> Value)
        -> Value
        {
        return self[key] ??
            {
            let newValue = newValue()
            self[key] = newValue
            return newValue
            }()
        }
    }

internal extension Set
    {
    mutating func filterInPlace(predicate: (Iterator.Element) -> Bool)
        {
        if !all(match: predicate)
            {
            // There's apparently no more performant way of doing this filter in place than creating a whole new set.
            // Even the stdlib’s internal implementation does this for its similar mutating union/intersection methods.

            self = Set(filter(predicate))
            }
        }
    }
