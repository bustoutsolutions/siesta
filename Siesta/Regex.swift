//
//  Regex.swift
//  Siesta
//
//  Created by Paul on 2015/7/8.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

extension String
    {
    func containsRegex(regex: String) -> Bool
        {
        return rangeOfString(regex, options: .RegularExpressionSearch) != nil
        }

    func match(regex: String) -> Bool
        {
        return rangeOfString(regex, options: .RegularExpressionSearch) != nil
        }
    
    func replaceRegex(regex: String, _ replacement: String) -> String
        {
        return stringByReplacingOccurrencesOfString(
            regex, withString: replacement, options: .RegularExpressionSearch, range: nil)
        }
    
    var fullRange: NSRange
        {
        return NSRange(location: 0, length: (self as NSString).length)
        }
    }

extension NSRegularExpression
    {
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
    
    func matches(string: String) -> Bool
        {
        let match = firstMatchInString(string, options: [], range: string.fullRange)
        return match != nil && match?.range.location != NSNotFound
        }
    
    func firstMatch(string: String) -> [String]?
        {
        guard let match = firstMatchInString(string, options: [], range: string.fullRange) else
            { return nil }
        
        return (0 ..< match.numberOfRanges)
            .map { match.rangeAtIndex($0) }
            .map((string as NSString).substringWithRange)
        }
    }
