//
//  String+Siesta.swift
//  Siesta
//
//  Created by Paul on 2015/6/22.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

extension String
    {
    func strippingPrefix(_ prefix: String) -> String
        {
        return hasPrefix(prefix)
            ? String(suffix(from: index(startIndex, offsetBy: prefix.count)))
            : self
        }

    func replacingPrefix(_ prefix: String, with replacement: String) -> String
        {
        return hasPrefix(prefix)
            ? replacement + strippingPrefix(prefix)
            : self
        }

    var capitalized: String
        {
        guard !isEmpty else
            { return self }
        let secondCharIndex = index(after: startIndex)
        return self[..<secondCharIndex].uppercased()
             + self[secondCharIndex...]
        }

    var nilIfEmpty: String?
        {
        return isEmpty ? nil : self
        }
    }
