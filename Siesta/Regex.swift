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

    func replaceRegex(regex: String, _ replacement: String) -> String
        {
        return stringByReplacingOccurrencesOfString(
            regex, withString: replacement, options: .RegularExpressionSearch, range: nil)
        }
    }

extension NSRegularExpression
    {
    func matches(string: String) -> Bool
        {
        let match = firstMatchInString(
            string,
            options: [],
            range: NSRange(location: 0, length: (string as NSString).length))
        return match != nil && match?.range.location != NSNotFound
        }
    }
