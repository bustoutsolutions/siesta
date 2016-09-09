//
//  WeakCache.swift
//  Siesta
//
//  Created by Paul on 2015/6/26.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation
#if os(OSX)
    internal let MemoryWarningNotification = "Siesta.MemoryWarningNotification"
#elseif os(iOS)
    import UIKit
    internal let MemoryWarningNotification = UIApplicationDidReceiveMemoryWarningNotification
#endif

/**
    A cache for maintaining a unique instance for a given key as long as any other objects
    retain references to it.
*/
internal final class WeakCache<K: Hashable, V: AnyObject>
    {
    private var entriesByKey = [K : WeakCacheEntry<V>]()
    private var lowMemoryObserver: AnyObject? = nil

    internal var countLimit = 2048
        {
        didSet { checkLimit() }
        }

    init()
        {
        lowMemoryObserver =
            NSNotificationCenter.defaultCenter().addObserverForName(
                MemoryWarningNotification,
                object: nil,
                queue: nil)
            {
            [weak self] _ in
            self?.flushUnused()
            }
        }

    deinit
        {
        if let lowMemoryObserver = lowMemoryObserver
            { NSNotificationCenter.defaultCenter().removeObserver(lowMemoryObserver) }
        }

    func get(key: K, @noescape onMiss: () -> V) -> V
        {
        return entriesByKey[key]?.value ??
            {
            checkLimit()
            let value = onMiss()
            entriesByKey[key] = WeakCacheEntry(value)
            return value
            }()
        }

    private func checkLimit()
        {
        if entriesByKey.count >= countLimit
            { flushUnused() }
        }

    func flushUnused()
        {
        for (key, entry) in entriesByKey
            {
            entry.allowRemoval()
            if entry.value == nil
                {
                // TODO: double lookup is inefficient; does Swift have a mutating iterator?
                entriesByKey.removeValueForKey(key)
                }
            }
        }

    var entries: AnySequence<(K,V)>
        {
        return AnySequence(
            entriesByKey.flatMap
                {
                (key, entry) -> (K,V)? in

                if let value = entry.value
                    { return (key, value) }
                else
                    { return nil }
                })
        }

    var keys: AnySequence<K>
        {
        return AnySequence(entries.map { $0.0 })
        }

    var values: AnySequence<V>
        {
        return AnySequence(entries.map { $0.1 })
        }
    }

private final class WeakCacheEntry<V: AnyObject>
    {
    private var ref: StrongOrWeakRef<V>

    init(_ value: V)
        {
        ref = StrongOrWeakRef(value)
        }

    var value: V?
        {
        ref.strong = true
        return ref.value
        }

    func allowRemoval()
        {
        ref.strong = false
        if let value = ref.value as? WeakCacheValue
            { value.allowRemovalFromCache() }
        }
    }

internal protocol WeakCacheValue
    {
    func allowRemovalFromCache()
    }
