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
    @warn_unused_result
    func containsRegex(regex: String) -> Bool
        {
        return rangeOfString(regex, options: .RegularExpressionSearch) != nil
        }

    @warn_unused_result
    func replacingRegex(regex: String, _ replacement: String) -> String
        {
        return stringByReplacingOccurrencesOfString(
            regex, withString: replacement, options: .RegularExpressionSearch, range: nil)
        }

    @warn_unused_result
    func replacingString(string: String, _ replacement: String) -> String
        {
        // Maybe this method name looked more reasonable in Objective-C.
        return stringByReplacingOccurrencesOfString(string, withString: replacement)
        }

    @warn_unused_result
    func replacingRegex(regex: NSRegularExpression, _ template: String) -> String
        {
        return regex.stringByReplacingMatchesInString(self, options: [], range: fullRange, withTemplate: template)
        }

    var fullRange: NSRange
        {
        return NSRange(location: 0, length: (self as NSString).length)
        }
    }

internal extension NSRegularExpression
    {
    @warn_unused_result
    static func compile(pattern: String, options: NSRegularExpressionOptions = [])
        -> NSRegularExpression
        {
        do  {
            return try NSRegularExpression(pattern: pattern, options: options)
            }
        catch
            {
            fatalError("Regexp compilation failed: \(pattern)")
            }
        }

    @warn_unused_result
    func matches(string: String) -> Bool
        {
        let match = firstMatchInString(string, options: [], range: string.fullRange)
        return match != nil && match?.range.location != NSNotFound
        }
    }
