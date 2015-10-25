//
//  ResourceStatusOverlay.swift
//  SiestaExample
//
//  Created by Paul on 2015/7/9.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Foundation

/**
  A ready-made UI component to show an activity indicator and/or error message for a set of `Resource`s.
  
  You can use this class in three ways:
  
  - with Siesta’s default layout,
  - with your own `.nib` file, or
  - using hard-coded layout.
*/
@objc(BOSResourceStatusOverlay)
public class ResourceStatusOverlay: UIView, ResourceObserver
    {
    @IBOutlet var containerView: UIView?
    @IBOutlet public var loadingIndicator: UIActivityIndicatorView?
    @IBOutlet public var errorView: UIView?
    @IBOutlet public var errorHeadline: UILabel?
    @IBOutlet public var errorDetail: UILabel?
    weak var parentVC: UIViewController?
    
    private var observedResources = [Resource]()
    
    override init(frame: CGRect)
        { super.init(frame: frame) }
    
    public convenience init()
        {
        self.init(nibName: "ResourceStatusOverlay", bundle: NSBundle(forClass: ResourceStatusOverlay.self))
        }
    
    public convenience init(
            nibName: String,
            bundle: NSBundle = NSBundle.mainBundle())
        {
        self.init(frame: CGRectZero)
        
        bundle.loadNibNamed(nibName, owner: self as NSObject, options: [:])
        guard let containerView = containerView else
            { fatalError("WARNING: xib \"\(nibName)\" did not set contentView of \(self)") }
        
        addSubview(containerView)
        containerView.frame = bounds
        containerView.autoresizingMask = [UIViewAutoresizing.FlexibleWidth,
                                          UIViewAutoresizing.FlexibleHeight]
        
        showSuccess()
        }

    public required init?(coder: NSCoder)
        { super.init(coder: coder) }
    
    public func embedIn(parentViewController: UIViewController) -> Self
        {
        self.parentVC = parentViewController
        
        layer.zPosition = 10000
        parentVC?.view.addSubview(self)
        
        backgroundColor = parentVC?.view.backgroundColor
        
        positionToCoverParent()
        
        return self
        }
    
    public func positionToCoverParent()
        {
        if let parentVC = parentVC
            {
            let parentSize = parentVC.view.bounds.size
            let top = parentVC.topLayoutGuide.length,
                bot = parentVC.bottomLayoutGuide.length
            self.positionToCoverRect(
                CGRectMake(top, 0, parentSize.width, parentSize.height - top - bot),
                inView: parentVC.view)
            }
        }

    public func positionToCover(view: UIView)
        {
        self.positionToCoverRect(view.bounds, inView: view)
        }
    
    /// Positions this view within its current superview so that it covers
    /// the given rect in the local coordinates of the given view.
    
    public func positionToCoverRect(rect: CGRect, inView srcView: UIView)
        {
        if let superview = self.superview
            {
            let ul = superview.convertPoint(rect.origin, fromView: srcView),
                br = superview.convertPoint(
                    CGPoint(x: rect.origin.x + rect.size.width,
                            y: rect.origin.y + rect.size.height),
                    fromView: srcView)
            frame = CGRectMake(ul.x, ul.y, br.x - ul.x, br.y - ul.y)  // Doesn’t handle crazy transforms. Too bad so sad!
            }
        }
    
    public func resourceChanged(resource: Resource, event: ResourceEvent)
        {
        if case .ObserverAdded = event
            { observedResources.append(resource) }
        
        var anyLoading = false
        
        for res in observedResources
            {
            if res.loading
                { anyLoading = true }
            else if let error = res.latestError
                { return showError(error) }
            }
        
        if anyLoading
            {
            showLoading()
            return
            }
        
        showSuccess()
        }

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

    @IBAction public func retryFailedRequests()
        {
        for res in observedResources
            where res.latestError != nil
                { res.loadIfNeeded() }
        }
    }
