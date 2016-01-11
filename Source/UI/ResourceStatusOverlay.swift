//
//  ResourceStatusOverlay.swift
//  SiestaExample
//
//  Created by Paul on 2015/7/9.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Foundation

/**
  A ready-made UI component to show an activity indicator and/or error message for a set of `Resource`s. Add this view
  as an observer of one or more resources. You can add it to your view hierarchy yourself, or use `embedIn(_:)`

  An overlay can be in exactly one of three states: **loading**, **success**, or **error**. It shows and hides child
  views depending on which state it’s in. The `displayPriority` property governs these states.
*/
@objc(BOSResourceStatusOverlay)
public class ResourceStatusOverlay: UIView, ResourceObserver
    {
    // MARK: Child views

    /// A view that is visible in the loading and error states, and hidden in the success state.
    @IBOutlet public var containerView: UIView?

    /// A view that is visible in the loading state, and hidden in all other states.
    @IBOutlet public var loadingIndicator: UIView?

    /// A view that is visible in the error state, and hidden in all other states.
    @IBOutlet public var errorView: UIView?

    /// Displays a generic message stating that an error occurred. You can change the text of this label to taste.
    @IBOutlet public var errorHeadline: UILabel?

    /// Displays `Error.userMessage`.
    @IBOutlet public var errorDetail: UILabel?

    private weak var parentVC: UIViewController?
    private var observedResources = [Resource]()
    private var retryRequestsInProgress = 0

    // MARK: Creating an overlay

    /**
      Creates a status overlay with the default layout.
    */
    public convenience init()
        {
        self.init(nibName: "ResourceStatusOverlay", bundle: NSBundle(forClass: ResourceStatusOverlay.self))
        }

    /**
      Creates a status overlay with your custom nib of choice. Your nib may bind as many or as few of the public
      `@IBOutlet`s as it likes.
    */
    public convenience init(
            nibName: String,
            bundle: NSBundle = NSBundle.mainBundle())
        {
        self.init(frame: CGRectZero)

        bundle.loadNibNamed(nibName, owner: self as NSObject, options: [:])

        if let containerView = containerView
            {
            addSubview(containerView)
            containerView.frame = bounds
            containerView.autoresizingMask = [UIViewAutoresizing.FlexibleWidth,
                                              UIViewAutoresizing.FlexibleHeight]
            }

        showSuccess()
        }

    /**
      Create an overlay with a programmatic layout.
    */
    override init(frame: CGRect)
        { super.init(frame: frame) }

    /**
      Create an overlay with a programmatic or serialized layout.
    */
    public required init?(coder: NSCoder)
        { super.init(coder: coder) }


    // MARK: Layout

    /**
      Place this child inside the given view controller’s view, and position it so that it covers the entire bounds.
      Be sure to call `positionToCoverParent()` from your `viewDidLayoutSubviews()` method.
    */
    public func embedIn(parentViewController: UIViewController) -> Self
        {
        parentVC = parentViewController

        layer.zPosition = 10000
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
            let top = parentVC.topLayoutGuide.length,
                bot = parentVC.bottomLayoutGuide.length
            bounds.origin.y += top
            bounds.size.height -= top + bot
            positionToCoverRect(bounds, inView: parentVC.view)
            }
        }

    /**
      Positions this overlay to exactly cover the given view. The two views do not have to be siblings; this method
      works across the view hierarchy.
    */
    public func positionToCover(view: UIView)
        {
        positionToCoverRect(view.bounds, inView: view)
        }

    /**
      Positions this view within its current superview so that it covers the given rect in the local coordinates of the
      given view. Has no effect if the overlay has no superview.
    */
    public func positionToCoverRect(rect: CGRect, inView srcView: UIView)
        {
        if let superview = superview
            {
            let ul = superview.convertPoint(rect.origin, fromView: srcView),
                br = superview.convertPoint(
                    CGPoint(x: rect.origin.x + rect.size.width,
                            y: rect.origin.y + rect.size.height),
                    fromView: srcView)
            frame = CGRectMake(ul.x, ul.y, br.x - ul.x, br.y - ul.y)  // Doesn’t handle crazy transforms. Too bad so sad!
            }
        }

    // MARK: State transition logic

    /**
      Changes the logic for determining whether an error message, a loading indicator, or existing data take precedence.

      The default priority is:

          [.Loading, .Error, .AnyData]

      If you instead prefer to _always_ show existing data, even if it is stale:

          [.AnyData, .Loading, .Error]  // What I think you want?

      If you have a timer refreshing a resource periodically in the background and don’t want that to trigger a loading
      indicator, but you _do_ want a manual refresh to show the indicator, then use:

          [.ManualLoading, .AnyData, .Error, .Loading]

      …and call `trackManualLoad(_:)` with your user-initiated request.
    */
    public var displayPriority: [StateRule] = [.Loading, .Error, .AnyData]

    /**
      Arbitrarily prioritizable rules for governing the behavior of `ResourceStatusOverlay`.

      - SeeAlso: `ResourceStatusOverlay.displayPriority`
    */
    public enum StateRule: String
        {
        /// If `Resource.isLoading` is true for any observed resources, enter the **loading** state.
        case Loading

        /// If any request passed to `ResourceStatusOverlay.trackManualLoad(_:)` is still in progress,
        /// enter the **loading** state.
        case ManualLoading

        /// If `Resource.latestData` is non-nil for _any_ observed resources, enter the **success** state.
        case AnyData

        /// If `Resource.latestData` is non-nil for _all_ observed resources, enter the **success** state.
        case AllData

        /// If `Resource.latestError` is non-nil for any observed resources, enter the **error** state.
        /// If multiple observed resources have errors, pick one arbitrarily to show its error message.
        case Error
        }

    /// :nodoc:
    public func resourceChanged(resource: Resource, event: ResourceEvent)
        {
        if case .ObserverAdded = event
            { observedResources.append(resource) }

        updateDisplay()
        }

    private func updateDisplay()
        {
        for mode in displayPriority
            {
            switch mode
                {
                case .Loading:
                    if observedResources.any({ $0.isLoading })
                        { return showLoading() }

                case .ManualLoading:
                    if retryRequestsInProgress > 0
                        { return showLoading() }

                case .AnyData:
                    if observedResources.any({ $0.latestData != nil })
                        { return showSuccess() }

                case .AllData:
                    if observedResources.all({ $0.latestData != nil })
                        { return showSuccess() }

                case .Error:
                    if let error = observedResources.flatMap({ $0.latestError }).first
                        { return showError(error) }
                }
            }

        showSuccess()
        }

    /// :nodoc:
    public func stoppedObservingResource(resource: Resource)
        {
        observedResources = observedResources.filter { $0 !== resource }
        }

    private func showError(error: Error)
        {
        hidden = false
        errorView?.hidden = false
        loadingIndicator?.hidden = true
        errorDetail?.text = error.userMessage
        }

    private func showLoading()
        {
        hidden = false
        errorView?.hidden = true
        loadingIndicator?.hidden = false
        loadingIndicator?.alpha = 0
        UIView.animateWithDuration(0.7) { self.loadingIndicator?.alpha = 1 }
        }

    private func showSuccess()
        {
        loadingIndicator?.hidden = true
        hidden = true
        }

    // MARK: Retry & reload

    /// Call `loadIfNeeded()` on any resources with errors that this overlay is observing.
    @IBAction public func retryFailedRequests()
        {
        for res in observedResources
            where res.latestError != nil
                {
                if let retryReq = res.loadIfNeeded()
                    { trackManualLoad(retryReq) }
                }
        }

    /// Enable `StateRule.ManualLoading` for the lifespan of the given request.
    public func trackManualLoad(request: Request)
        {
        retryRequestsInProgress += 1
        updateDisplay()

        request.onCompletion
            {
            [weak self] _ in
            guard let overlay = self else
                { return }

            overlay.retryRequestsInProgress -= 1
            overlay.updateDisplay()
            }
        }
    }
