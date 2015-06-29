//
//  WeakCache.swift
//  Siesta
//
//  Created by Paul on 2015/6/26.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

class WeakCache<K: Hashable, V: AnyObject>
    {
    private var entries = [K : WeakCacheEntry<V>]()
    private var lowMemoryObserver: NSObjectProtocol?
    
    init()
        {
        lowMemoryObserver = NSNotificationCenter.defaultCenter().addObserverForName(
                UIApplicationDidReceiveMemoryWarningNotification,
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
    
    func get(key: K, onMiss: () -> V) -> V
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
        for entry in entries.values
            { entry.allowRemoval() }
        for (key, entry) in entries
            where entry.value == nil
            {
            // TODO: double lookup is inefficient; also, Swift dictionary allows concurrent mod??
            entries.removeValueForKey(key)
            }
        }
    }

private class WeakCacheEntry<V: AnyObject>
    {
    private(set) weak var valueWeak: V?
    private(set) var valueStrong: V?
    
    init(_ value: V)
        {
        valueWeak   = value
        valueStrong = value
        }
    
    var value: V?
        {
        valueStrong = valueWeak
        return valueWeak
        }
    
    func allowRemoval()
        {
        valueStrong = nil
        }
    }
