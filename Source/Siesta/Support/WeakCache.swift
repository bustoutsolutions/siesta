//
//  WeakCache.swift
//  Siesta
//
//  Created by Paul on 2015/6/26.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation
#if os(OSX) || os(watchOS)
    internal let MemoryWarningNotification = NSNotification.Name("Siesta.MemoryWarningNotification")
#elseif os(iOS) || os(tvOS)
    import UIKit
    internal let MemoryWarningNotification = NSNotification.Name.UIApplicationDidReceiveMemoryWarning
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
            NotificationCenter.default.addObserver(
                forName: MemoryWarningNotification,
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
            { NotificationCenter.default.removeObserver(lowMemoryObserver) }
        }

    func get(_ key: K, onMiss: () -> V) -> V
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
                // TODO: prevent double lookup if something like this proposal ever gets implemented:
                // https://gist.github.com/natecook1000/473720ba072fa5a0cd5e6c913de75fe1
                entriesByKey.removeValue(forKey: key)
                }
            }
        }

    var entries: AnySequence<(K, V)>
        {
        return AnySequence(
            entriesByKey.flatMap
                {
                (key, entry) -> (K, V)? in

                if let value = entry.value
                    { return (key, value) }
                else
                    { return nil }
                }
            )
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
        ref.strong = true  // Any access promotes to strong ref until next memory event
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
