//
//  Regex.swift
//  Siesta
//
//  Created by Paul on 2015/7/8.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

internal extension String
    {
    func contains(regex: String) -> Bool
        {
        return range(of: regex, options: .regularExpression) != nil
        }

    func replacing(regex: String, with replacement: String) -> String
        {
        return replacingOccurrences(
            of: regex, with: replacement, options: .regularExpression, range: nil)
        }

    func replacing(regex: NSRegularExpression, with template: String) -> String
        {
        return regex.stringByReplacingMatches(in: self, options: [], range: fullRange, withTemplate: template)
        }

    fileprivate var fullRange: NSRange
        {
        return NSRange(location: 0, length: (self as NSString).length)
        }
    }

internal extension NSRegularExpression
    {
    func matches(_ string: String) -> Bool
        {
        let match = firstMatch(in: string, options: [], range: string.fullRange)
        return match != nil && match?.range.location != NSNotFound
        }
    }
