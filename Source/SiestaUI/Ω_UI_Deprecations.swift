//
//  Ω_Deprecations.swift
//  Siesta
//
//  Created by Paul on 2016/11/15.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Siesta
import UIKit
import Foundation

extension ResourceStatusOverlay
    {
    @available(*, deprecated: 0.99, renamed: "load(fromNib:bundle:)")
    open func loadFrom(nibName: String, bundle: Bundle = Bundle.main)
        { load(fromNib: nibName, bundle: bundle) }

    @available(*, deprecated: 0.99, renamed: "embed(in:)")
    @nonobjc @discardableResult
    public func embedIn(_ parentViewController: UIViewController) -> Self
        { return embed(in: parentViewController) }

    @available(*, deprecated: 0.99, renamed: "positionToCover(_:)")
    public func positionToCoverRect(_ rect: CGRect, inView srcView: UIView)
        { positionToCover(rect, inView: srcView) }
    }

extension ResourceStatusOverlay.StateRule
    {
    @available(*, deprecated: 0.99, renamed: "loading")
    public static let Loading = ResourceStatusOverlay.StateRule.loading

    @available(*, deprecated: 0.99, renamed: "manualLoading")
    public static let ManualLoading = ResourceStatusOverlay.StateRule.manualLoading

    @available(*, deprecated: 0.99, renamed: "anyData")
    public static let AnyData = ResourceStatusOverlay.StateRule.anyData

    @available(*, deprecated: 0.99, renamed: "allData")
    public static let AllData = ResourceStatusOverlay.StateRule.allData

    @available(*, deprecated: 0.99, renamed: "error")
    public static let Error = ResourceStatusOverlay.StateRule.error
    }
