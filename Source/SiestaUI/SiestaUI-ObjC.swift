//
//  SiestaUI-ObjC.swift
//  Siesta
//
//  Created by Paul on 2016/8/17.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation
#if !COCOAPODS
    import Siesta
#endif

#if !os(OSX)

extension ResourceEvent
    {
    internal static let all = [observerAdded, requested, requestCancelled, notModified, error,
                               newData(.network), newData(.cache), newData(.localOverride), newData(.wipe)]

    internal static func fromDescription(_ description: String) -> ResourceEvent?
        {
        let matching = ResourceEvent.all.filter { $0._objc_stringForm == description }
        return (matching.count == 1) ? matching[0] : nil
        }
    }

extension ResourceStatusOverlay: _objc_ResourceObserver
    {
    public func resourceChanged(_ resource: Resource, event eventString: String)
        {
        if let event = ResourceEvent.fromDescription(eventString)
            { resourceChanged(resource, event: event) }
        else
            { print("WARNING: Siesta ignoring unknown event: \(eventString)") }
        }
    }

extension ResourceStatusOverlay
    {
    @objc(displayPriority)
    public var _objc_displayPriority: [String]
        {
        get {
            return displayPriority.map { $0.rawValue }
            }

        set {
            displayPriority = newValue.flatMap
                {
                let condition = ResourceStatusOverlay.StateRule(rawValue: $0)
                if condition == nil
                    { print("WARNING: Siesta ignoring unknown ResourceStatusOverlay.StateRule \"\($0)\"") }
                return condition
                }
            }
        }
    }

#endif
