//
//  OSX.swift
//  Siesta
//
//  Created by Cédric Foellmi on 22/05/16.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation
import CoreGraphics

#if os(OSX)
    import AppKit

    public typealias BOSView=NSView
    public typealias BOSViewAutoresizing=NSAutoresizingMaskOptions
    public typealias BOSViewController=NSViewController

    public typealias BOSLabel=NSTextField
    public typealias BOSImageView=NSImageView
    public typealias BOSImage=NSImage
    public typealias BOSColor=NSColor
#else
    import UIKit
    
    public typealias BOSView=UIView
    public typealias BOSViewAutoresizing=UIViewAutoresizing
    public typealias BOSViewController=UIViewController

    public typealias BOSLabel=UILabel
    public typealias BOSImageView=UIImageView
    public typealias BOSImage=UIImage
    public typealias BOSColor=UIColor
#endif


#if os(OSX)
    // NSTextField is OSX's UILabel, and it inherits from NSControl
    extension NSControl {
        // on OSX, there's no "text" property, but we have the old-Cocoa "value" methods common to many Foundation types.
        public var text: String {
            get { return self.stringValue }
            set { self.stringValue = newValue }
        }
    }
    
    extension NSView {
        // I guess Apple engineers preferred to not stick to that same old-Cocoa "value" methods when building UIKit?
        public var alpha: CGFloat {
            get { return self.alphaValue }
            set { self.alphaValue = newValue }
        }
        
        public var backgroundColor: NSColor? {
            get {
                guard self.layer != nil, let cgColor = self.layer!.backgroundColor else {
                    return nil
                }
                return NSColor(CGColor: cgColor)
            }
            set {
                let nsColor = newValue as NSColor?
                if nsColor != nil {
                    self.layer!.backgroundColor = nsColor!.CGColor
                }
            }
        }
        
        class func animateWithDuration(duration: NSTimeInterval, animations: () -> Void) {
            NSAnimationContext.beginGrouping()
            NSAnimationContext.currentContext().duration = duration
            animations()
            NSAnimationContext.endGrouping()
        }
    }
    
    // This is to make UIView's resizing mask working.
    extension NSAutoresizingMaskOptions {
        static var None: NSAutoresizingMaskOptions { return ViewNotSizable }
        static var FlexibleLeftMargin: NSAutoresizingMaskOptions { return ViewMinXMargin }
        static var FlexibleWidth: NSAutoresizingMaskOptions { return ViewWidthSizable }
        static var FlexibleRightMargin: NSAutoresizingMaskOptions { return ViewMaxXMargin }
        static var FlexibleTopMargin: NSAutoresizingMaskOptions { return ViewMinYMargin }
        static var FlexibleHeight: NSAutoresizingMaskOptions { return ViewHeightSizable }
        static var FlexibleBottomMargin: NSAutoresizingMaskOptions { return ViewMaxYMargin }
    }
    
    extension NSBundle {
        func loadNibNamed(name: String!, owner: AnyObject!, options: [NSObject : AnyObject]!) -> [AnyObject]! {
            var topLevels: NSArray?
            let success = self.loadNibNamed(name, owner: owner, topLevelObjects: &topLevels)
            return (success == true) ? topLevels as! [AnyObject] : []
        }
    }
    
#endif
