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
    @IBOutlet public var containerView: UIView?
    @IBOutlet public var loadingIndicator: UIActivityIndicatorView?
    @IBOutlet public var errorView: UIView?
    @IBOutlet public var errorHeadline: UILabel?
    @IBOutlet public var errorDetail: UILabel?
    weak var parentVC: UIViewController?
    
    public var displayPriority: [Condition] = [.Loading, .Error, .AnyData]
    
    private var observedResources = [Resource]()
    private var retryRequestsInProgress = 0
    
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
        
        if let containerView = containerView
            {
            addSubview(containerView)
            containerView.frame = bounds
            containerView.autoresizingMask = [UIViewAutoresizing.FlexibleWidth,
                                              UIViewAutoresizing.FlexibleHeight]
            }
        
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
            var bounds = parentVC.view.bounds
            let top = parentVC.topLayoutGuide.length,
                bot = parentVC.bottomLayoutGuide.length
            bounds.origin.y += top
            bounds.size.height -= top + bot
            self.positionToCoverRect(bounds, inView: parentVC.view)
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
        
        updateDisplay()
        }
    
    private func updateDisplay()
        {
        for mode in displayPriority
            {
            switch(mode)
                {
                case .Loading:
                    if observedResources.any({ $0.loading })
                        { return showLoading() }
                
                case .Retrying:
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
                {
                if let retryReq = res.loadIfNeeded()
                    { addRetryRequest(retryReq) }
                }
        }
    
    private func addRetryRequest(request: Request)
        {
        ++retryRequestsInProgress
        self.updateDisplay()
        
        request.completion
            {
            [weak self] _ in
            guard let overlay = self else { return }
            
            --overlay.retryRequestsInProgress
            overlay.updateDisplay()
            }
        }
    
    public enum Condition: String
        {
        case Loading
        case Retrying
        case AnyData
        case AllData
        case Error
        }
    }
