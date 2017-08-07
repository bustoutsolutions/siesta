//
//  ResourceStatusOverlay.swift
//  SiestaExample
//
//  Created by Paul on 2015/7/9.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

#if !COCOAPODS
    import Siesta
#endif
import Foundation
import CoreGraphics
import UIKit

/**
  A ready-made UI component to show an activity indicator and/or error message for a set of `Resource`s. Add this view
  as an observer of one or more resources. You can add it to your view hierarchy yourself, or use `embedIn(_:)`

  An overlay can be in exactly one of three states: **loading**, **success**, or **error**. It shows and hides child
  views depending on which state it’s in. The `displayPriority` property governs these states.
*/
open class ResourceStatusOverlay: UIView, ResourceObserver
    {
    // MARK: Child views

    /// A view that is visible in the loading and error states, and hidden in the success state.
    @IBOutlet open var containerView: UIView?

    /// A view that is visible in the loading state, and hidden in all other states.
    @IBOutlet open var loadingIndicator: UIView?

    /// A view that is visible in the error state, and hidden in all other states.
    @IBOutlet open var errorView: UIView?

    /// Displays a generic message stating that an error occurred. You can change the text of this label to taste.
    @IBOutlet open var errorHeadline: UILabel?

    /// Displays `RequestError.userMessage`.
    @IBOutlet open var errorDetail: UILabel?

    /// Allow user to retry a failed request.
    @IBOutlet open var retryButton: UIButton!

    private weak var parentVC: UIViewController?
    private var observedResources = [Resource]()
    private var manualLoadsInProgress = 0

    // MARK: Creating an overlay

    /**
      Creates a status overlay with the default layout.
    */
    public required init()
        {
        super.init(frame: CGRect.zero)
        load(
            fromNib: "ResourceStatusOverlay",
            bundle: Bundle(for: ResourceStatusOverlay.self))
        }

    /**
      Create an overlay with a programmatic layout.
    */
    public override init(frame: CGRect)
        { super.init(frame: frame) }

    /**
      Create an overlay with a programmatic or serialized layout.
    */
    public required init?(coder: NSCoder)
        { super.init(coder: coder) }

    /**
      Populates a status overlay with your custom nib of choice. Your nib may bind as many or as few of the public
      `@IBOutlet`s as it likes.
    */
    open func load(
            fromNib nibName: String,
            bundle: Bundle = Bundle.main)
        {
        bundle.loadNibNamed(nibName, owner: self as NSObject, options: [:])

        if let containerView = containerView
            {
            addSubview(containerView)
            containerView.frame = bounds
            containerView.autoresizingMask = [UIViewAutoresizing.flexibleWidth,
                                              UIViewAutoresizing.flexibleHeight]
            }

        showSuccess()
        }

    // MARK: Layout

    /**
      Place this child inside the given view controller’s view, and position it so that it covers the entire bounds.
      Be sure to call `positionToCoverParent()` from your `viewDidLayoutSubviews()` method.
    */
    @discardableResult
    public func embed(in parentViewController: UIViewController) -> Self
        {
        parentVC = parentViewController

        // For explanations of the os() function:
        // https://developer.apple.com/library/ios/documentation/Swift/Conceptual/BuildingCocoaApps/InteractingWithCAPIs.html#//apple_ref/doc/uid/TP40014216-CH8-XID_20
        #if os(iOS)
            layer.zPosition = 10000
        #endif
        parentVC?.view.addSubview(self)

        backgroundColor = parentVC?.view.backgroundColor

        positionToCoverParent()

        return self
        }

    /**
      Repositions this view to conver the view controller’s content area. Has no effect unless this overlay was embedded
      using `embedIn(_:)`.
    */
    public func positionToCoverParent()
        {
        if let parentVC = parentVC
            {
            var bounds = parentVC.view.bounds
            #if !os(OSX)
                let top = parentVC.topLayoutGuide.length,
                    bot = parentVC.bottomLayoutGuide.length
                bounds.origin.y += top
                bounds.size.height -= top + bot
            #endif
            positionToCover(bounds, inView: parentVC.view)
            }
        }

    /**
      Positions this overlay to exactly cover the given view. The two views do not have to be siblings; this method
      works across the view hierarchy.
    */
    public func positionToCover(_ view: UIView)
        {
        positionToCover(view.bounds, inView: view)
        }

    /**
      Positions this view within its current superview so that it covers the given rect in the local coordinates of the
      given view. Has no effect if the overlay has no superview.
    */
    public func positionToCover(_ rect: CGRect, inView srcView: UIView)
        {
        if let superview = superview
            {
            let ul = superview.convert(rect.origin, from: srcView),
                br = superview.convert(
                    CGPoint(x: rect.origin.x + rect.size.width,
                            y: rect.origin.y + rect.size.height),
                    from: srcView)
            frame = CGRect(x: ul.x, y: ul.y, width: br.x - ul.x, height: br.y - ul.y)  // Doesn’t handle crazy transforms. Too bad so sad!
            }
        }

    // MARK: State transition logic

    /**
      Changes the logic for determining whether an error message, a loading indicator, or existing data take precedence.

      The default priority is:

          [.loading, .error, .anyData]

      If you instead prefer to _always_ show existing data, even if it is stale:

          [.anyData, .loading, .error]  // What I think you want?

      If you have a timer refreshing a resource periodically in the background and don’t want that to trigger a loading
      indicator, but you _do_ want a manual refresh to show the indicator, then use:

          [.manualLoading, .anyData, .error, .loading]

      …and call `trackManualLoad(_:)` with your user-initiated request.
    */
    public var displayPriority: [StateRule] = [.loading, .error, .anyData]

    /**
      Arbitrarily prioritizable rules for governing the behavior of `ResourceStatusOverlay`.

      - SeeAlso: `ResourceStatusOverlay.displayPriority`
    */
    public enum StateRule: String
        {
        /// If `Resource.isLoading` is true for any observed resources, enter the **loading** state.
        case loading

        /// If any request passed to `ResourceStatusOverlay.trackManualLoad(_:)` is still in progress,
        /// enter the **loading** state.
        case manualLoading

        /// If `Resource.latestData` is non-nil for _any_ observed resources, enter the **success** state.
        case anyData

        /// If `Resource.latestData` is non-nil for _all_ observed resources, enter the **success** state.
        case allData

        /// If `Resource.latestError` is non-nil for any observed resources, enter the **error** state.
        /// If multiple observed resources have errors, pick one arbitrarily to show its error message.
        case error
        }

    /// :nodoc:
    open func resourceChanged(_ resource: Resource, event: ResourceEvent)
        {
        if case .observerAdded = event
            { observedResources.append(resource) }

        updateDisplay()
        }

    private func updateDisplay()
        {
        for mode in displayPriority
            {
            switch mode
                {
                case .loading:
                    if observedResources.any(match: { $0.isLoading })
                        { return showLoading() }

                case .manualLoading:
                    if manualLoadsInProgress > 0
                        { return showLoading() }

                case .anyData:
                    if observedResources.any(match: { $0.latestData != nil })
                        { return showSuccess() }

                case .allData:
                    if observedResources.all(match: { $0.latestData != nil })
                        { return showSuccess() }

                case .error:
                    if let error = observedResources.flatMap({ $0.latestError }).first
                        { return showError(error) }
                }
            }

        showSuccess()
        }

    /// :nodoc:
    open func stoppedObserving(resource: Resource)
        {
        observedResources = observedResources.filter { $0 !== resource }
        updateDisplay()
        }

    private func showError(_ error: RequestError)
        {
        isHidden = false
        errorView?.isHidden = false
        loadingIndicator?.isHidden = true
        errorDetail?.text = error.userMessage
        }

    private func showLoading()
        {
        isHidden = false
        errorView?.isHidden = true
        loadingIndicator?.isHidden = false
        loadingIndicator?.alpha = 0
        UIView.animate(withDuration: 0.7) { self.loadingIndicator?.alpha = 1 }
        }

    private func showSuccess()
        {
        loadingIndicator?.isHidden = true
        isHidden = true
        }

    // MARK: Retry & reload

    /// Call `loadIfNeeded()` on any resources with errors that this overlay is observing.
    public func retryFailedRequests()
        {
        for res in observedResources
            where res.latestError != nil
                {
                if let retryReq = res.loadIfNeeded()
                    { trackManualLoad(retryReq) }
                }
        }

    /// Variant of `retryFailedRequests()` suitable for use as an IBOutlet. (The `sender` is ignored.)
    @IBAction public func retryFailedRequests(_ sender: Any)
        {
        retryFailedRequests()
        }

    /// Enable `StateRule.manualLoading` for the lifespan of the given request.
    public func trackManualLoad(_ request: Request)
        {
        manualLoadsInProgress += 1
        updateDisplay()

        request.onCompletion
            {
            [weak self] _ in
            guard let overlay = self else
                { return }

            overlay.manualLoadsInProgress -= 1
            overlay.updateDisplay()
            }
        }
    }
