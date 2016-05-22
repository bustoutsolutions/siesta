//
//  Collection+Siesta.swift
//  Siesta
//
//  Created by Paul on 2015/7/19.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

internal extension CollectionType
    {
    @warn_unused_result
    func bipartition(
            @noescape includeElement: (Self.Generator.Element) -> Bool)
        -> (included: [Self.Generator.Element], excluded: [Self.Generator.Element])
        {
        var included: [Self.Generator.Element] = []
        var excluded: [Self.Generator.Element] = []

        for elem in self
            {
            if includeElement(elem)
                { included.append(elem) }
            else
                { excluded.append(elem) }
            }

        return (included: included, excluded: excluded)
        }
    }

internal extension Array
    {
    @warn_unused_result
    func any(@noescape predicate: Generator.Element -> Bool) -> Bool
        {
        for elem in self
            where predicate(elem)
                { return true }
        return false
        }

    @warn_unused_result
    func all(@noescape predicate: Generator.Element -> Bool) -> Bool
        {
        return !any { !predicate($0) }
        }

    mutating func remove(@noescape predicate: Generator.Element -> Bool)
        {
        var dst = startIndex
        for src in indices
            {
            let elem = self[src]
            if !predicate(elem)
                {
                self[dst] = elem
                dst = dst.advancedBy(1)
                }
            }
        removeRange(dst ..< endIndex)
        }
    }

internal extension Dictionary
    {
    @warn_unused_result
    static func fromArray<K,V>(arrayOfTuples: [(K,V)]) -> [K:V]
        {
        var dict = Dictionary<K,V>(minimumCapacity: arrayOfTuples.count)
        for (k,v) in arrayOfTuples
            { dict[k] = v }
        return dict
        }

    @warn_unused_result
    func mapDict<MappedKey,MappedValue>(@noescape transform: (Key,Value) -> (MappedKey,MappedValue))
        -> [MappedKey:MappedValue]
        {
        return Dictionary.fromArray(map(transform))
        }

    @warn_unused_result
    func flatMapDict<MappedKey,MappedValue>(@noescape transform: (Key,Value) -> (MappedKey?,MappedValue?))
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
    }
