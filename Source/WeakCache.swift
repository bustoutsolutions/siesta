//
//  WeakCache.swift
//  Siesta
//
//  Created by Paul on 2015/6/26.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

/**
    A cache for maintaining a unique instance for a given key as long as any other objects
    retain references to it.
*/
internal class WeakCache<K: Hashable, V: AnyObject>
    {
    private var entries = [K : WeakCacheEntry<V>]()
    
    init()
        {
        // TODO: Apparently no longer necessary to call removeObserver() explicitly?
        NSNotificationCenter.defaultCenter().addObserverForName(
                UIApplicationDidReceiveMemoryWarningNotification,
                object: nil,
                queue: nil)
            {
            [weak self] _ in
            self?.flushUnused()
            }
        }

    func get(key: K, @noescape onMiss: () -> V) -> V
        {
        return entries[key]?.value ??
            {
            let value = onMiss()
            entries[key] = WeakCacheEntry(value)
            return value
            }()
        }
    
    func flushUnused()
        {
        for (key, entry) in entries
            {
            entry.allowRemoval()
            if entry.value == nil
                {
                // TODO: double lookup is inefficient; does Swift have a mutating iterator?
                entries.removeValueForKey(key)
                }
            }
        }
    }

private class WeakCacheEntry<V: AnyObject>
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
        }
    }
