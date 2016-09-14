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
    func containsRegex(_ regex: String) -> Bool
        {
        return range(of: regex, options: .regularExpression) != nil
        }

    func replacingRegex(_ regex: String, _ replacement: String) -> String
        {
        return replacingOccurrences(
            of: regex, with: replacement, options: .regularExpression, range: nil)
        }

    func replacingString(_ string: String, _ replacement: String) -> String
        {
        // Maybe this method name looked more reasonable in Objective-C.
        return replacingOccurrences(of: string, with: replacement)
        }

    func replacingRegex(_ regex: NSRegularExpression, _ template: String) -> String
        {
        return regex.stringByReplacingMatches(in: self, options: [], range: fullRange, withTemplate: template)
        }

    var fullRange: NSRange
        {
        return NSRange(location: 0, length: (self as NSString).length)
        }
    }

internal extension NSRegularExpression
    {
    static func compile(_ pattern: String, options: NSRegularExpression.Options = [])
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

    func matches(_ string: String) -> Bool
        {
        let match = firstMatch(in: string, options: [], range: string.fullRange)
        return match != nil && match?.range.location != NSNotFound
        }
    }
