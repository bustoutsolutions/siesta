//
//  Logging.swift
//  Siesta
//
//  Created by Paul on 2015/7/14.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Foundation

/// Enables debug logging.
public var debug = false

internal func debugLog(@autoclosure messageParts: () -> [Any?])
    {
    if debug
        {
        print("[Siesta] \(debugStr(messageParts()))")
        }
    }

private let whitespacePat = NSRegularExpression.compile("\\s+")

internal func debugStr(
        messageParts: [Any?],
        join: String = " ",
        consolidateWhitespace: Bool = true,
        truncate: Int? = 300)
    -> String
    {
    return " ".join(
        messageParts.map
            {
            ($0 as? String)
                ?? debugStr($0, consolidateWhitespace: consolidateWhitespace, truncate: truncate)
            })
    }

internal func debugStr(
        x: Any?,
        consolidateWhitespace: Bool = false,
        truncate: Int? = 500)
    -> String
    {
    guard let x = x else
        { return "–" }
    
    var s: String
    if let debugPrintable = x as? CustomDebugStringConvertible
        { s = debugPrintable.debugDescription ?? "–" }
    else
        { s = "\(x)" }
    
    if consolidateWhitespace
        { s = s.replaceRegex(whitespacePat, " ") }
    
    if let truncate = truncate where s.characters.count > truncate
        { s = s.substringToIndex(advance(s.startIndex, truncate)) + "…" }
    
    return s
    }
