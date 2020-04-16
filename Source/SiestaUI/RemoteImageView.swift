//
//  RemoteImageView.swift
//  Siesta
//
//  Created by Paul on 2015/8/26.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

#if os(iOS) || os(tvOS)

#if !COCOAPODS
    import Siesta
#endif
import UIKit
import Foundation

/**
  A `UIImageView` that asynchronously loads and displays remote images.
*/
open class RemoteImageView: UIImageView
    {
    /// Optional view to show while image is loading.
    @IBOutlet public weak var loadingView: UIView?

    /// Optional view to show if image is unavailable. Not shown while image is loading.
    @IBOutlet public weak var alternateView: UIView?

    /// Optional image to show if image is either unavailable or loading. Suppresses alternateView if non-nil.
    @IBInspectable public var placeholderImage: UIImage?

    /// The default service to cache `RemoteImageView` images.
    @objc
    public static var defaultImageService = Service()

    /// The service this view should use to request & cache its images.
    @objc
    public var imageService: Service = RemoteImageView.defaultImageService

    /// A URL whose content is the image to display in this view.
    @objc
    public var imageURL: String?
        {
        get { return imageResource?.url.absoluteString }
        set {
            imageResource = (newValue == nil)
                ? nil
                : imageService.resource(absoluteURL: newValue)
            }
        }

    /// Optional image transform applyed to placeholderImage and downloaded image
    @objc
    public var imageTransform: (UIImage?) -> UIImage? = { $0 }

    /**
      A remote resource whose content is the image to display in this view.

      If this image is already in memory, it is displayed synchronously (no flicker!). If the image is missing or
      potentially stale, setting this property triggers a load.
    */
    @objc
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
                { [weak self] _,_ in self?.updateViews() }

            if imageResource == nil  // (and thus closure above was not called on observerAdded)
                { updateViews() }
            }
        }

    private func updateViews()
        {
        image = imageTransform(imageResource?.typedContent(ifNone: placeholderImage))

        let isLoading = imageResource?.isLoading ?? false
        loadingView?.isHidden = !isLoading
        alternateView?.isHidden = (image != nil) || isLoading
        }
    }

#endif // OS
