//
//  ResourceStatusOverlay.swift
//  SiestaExample
//
//  Created by Paul on 2015/7/9.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Foundation

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
    
    public convenience init(
            nibName: String = "ResourceStatusOverlay",
            bundle: NSBundle = NSBundle(forClass: ResourceStatusOverlay.self))
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
    
    public func embedIn(parentViewController: UIViewController)
        -> Self
        {
        self.parentVC = parentViewController
        
        layer.zPosition = 10000
        parentVC?.view.addSubview(self)
        
        containerView?.backgroundColor = parentVC?.view.backgroundColor
        
        positionToCoverParent()
        
        return self
        }
    
    public func positionToCoverParent()
        {
        if let parentVC = parentVC
            {
            let parentSize = parentVC.view.frame.size
            let top = parentVC.topLayoutGuide.length,
                bot = parentVC.bottomLayoutGuide.length
            frame = CGRectMake(0, 0, parentSize.width, parentSize.height - top - bot)
            }
        }

    public func resourceChanged(resource: Resource, event: ResourceEvent)
        {
        if event == .ObserverAdded
            { observedResources.append(resource) }
        
        var anyLoading = false
        
        for res in observedResources
            {
            if(res.loading)
                { anyLoading = true }
            else if let error = res.latestError
                { return showError(error) }
            }
        
        if(anyLoading)
            {
            showLoading()
            return;
            }
        
        showSuccess()
        }

    public func stoppedObservingResource(resource: Resource)
        {
        observedResources = observedResources.filter { $0 !== resource }
        }
    
    private func showError(error: Resource.Error)
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
        UIView.animateWithDuration(0.7) { loadingIndicator?.alpha = 1 }
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
