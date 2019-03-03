//
//  Collection+Siesta.swift
//  Siesta
//
//  Created by Paul on 2015/7/19.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

extension Collection
    {
    // Just for readability
    func any(match predicate: (Iterator.Element) -> Bool) -> Bool
        { return contains(where: predicate) }

    func all(match predicate: (Iterator.Element) -> Bool) -> Bool
        { return !contains(where: { !predicate($0) }) }
    }

extension Dictionary
    {
    static func fromArray<K, V>(_ arrayOfTuples: [(K, V)]) -> [K:V]
        {
        // swiftlint:disable syntactic_sugar
        var dict = Dictionary<K, V>(minimumCapacity: arrayOfTuples.count)
        for (k, v) in arrayOfTuples
            { dict[k] = v }
        return dict
        // swiftlint:enable syntactic_sugar
        }

    func mapDict<MappedKey, MappedValue>(transform: (Key, Value) -> (MappedKey, MappedValue))
        -> [MappedKey:MappedValue]
        {
        return Dictionary.fromArray(map(transform))
        }

    func flatMapDict<MappedKey, MappedValue>(transform: (Key, Value) -> (MappedKey?, MappedValue?))
        -> [MappedKey:MappedValue]
        {
        return Dictionary.fromArray(
            compactMap
                {
                let (k, v) = transform($0, $1)
                if let k = k, let v = v
                    { return (k, v) }
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

    mutating func removeValues(matching predicate: (Value) -> Bool) -> Bool
        {
        var anyRemoved = false
        for (key, value) in self
            {
            if predicate(value)
                {
                removeValue(forKey: key)
                anyRemoved = true
                }
            }
        return anyRemoved
        }
    }

extension Set
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
