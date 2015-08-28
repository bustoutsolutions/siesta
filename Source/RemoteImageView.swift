//
//  RemoteImageView.swift
//  Siesta
//
//  Created by Paul on 2015/8/26.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//


/**
  A `UIImageView` that asynchronously loads and displays remote images.
*/
public class RemoteImageView: UIImageView
    {
    /// Optional view to show while image is loading
    @IBOutlet public weak var loadingView: UIView?
    
    /// Optional view to show if image load fails
    @IBOutlet public weak var alternateView: UIView?
    
    /**
      A remote resource whose content is the image to display.
      
      If this image has already been loaded, it is display immediately (no flicker). If the image is missing or
      potentially stale, setting the resource triggers a server request.
    */
    public var imageResource: Resource?
        {
        willSet
            {
            imageResource?.removeObservers(ownedBy: self)
            imageResource?.cancelLoadIfUnobserved(afterDelay: 0.05)
            }
        
        didSet
            {
            imageResource?.loadIfNeeded()
            imageResource?.addObserver(owner: self)
                { [weak self] _ in self?.updateViews() }
            
            if imageResource == nil
                { updateViews() }
            }
        }

    private func updateViews()
        {
        image = imageResource?.contentAsType(ifNone: placeholderImage)
        
        let loading = imageResource?.loading ?? false
        loadingView?.hidden = !loading
        alternateView?.hidden = (image != nil) || loading
        }
    }
