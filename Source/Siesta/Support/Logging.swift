//
//  Logging.swift
//  Siesta
//
//  Created by Paul on 2015/7/14.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

/**
  Controls which message Siesta will log. See `enabledLogCategories`.

  - SeeAlso: [Logging Guide](https://github.com/bustoutsolutions/siesta/blob/master/Docs/logging.md)
*/
public enum LogCategory
    {
    /// Summary of network requests: HTTP method, URL, and result code.
    case network

    /// Details of network requests, including headers and bodies.
    case networkDetails

    /// Details of how the `ResponseTransformer` parses responses.
    case pipeline

    /// `ResourceEvent` broadcast by resources.
    case stateChanges

    /// Detailed information about when observers are added, when they are removed, and which events they receive.
    case observers

    /// Information about how `Resource.loadIfNeeded()` decides whether to initiate a request.
    case staleness

    /// Details of when resource data is read from & saved to a persistent cache
    case cache

    /// Details of which configuration matches which resources, and when it is computed.
    case configuration

    // MARK: Predefined subsets

    /// A reasonable subset of log categories for normal debugging.
    public static let common: Set<LogCategory> = [network, stateChanges, staleness]

    /// Everything except full request/response data.
    public static let detailed = Set<LogCategory>(all.filter { $0 != networkDetails})

    /// The whole schebang!
    public static let all: Set<LogCategory> = [network, networkDetails, pipeline, stateChanges, observers, staleness, cache, configuration]

    /// The set of categories to log. Can be changed at runtime.
    public static var enabled = Set<LogCategory>()
    }

private let maxCategoryNameLength = LogCategory.all.map { Int(String(describing: $0).characters.count) }.max() ?? 0

/// Inject your custom logger to do something other than print to stdout.
public var logger: (LogCategory, String) -> Void =
    {
    let paddedCategory = String(describing: $0).padding(toLength: maxCategoryNameLength, withPad: " ", startingAt: 0)
    var threadName = ""
    if !Thread.isMainThread
        {
        threadName += "[thread "
        var threadID = abs(ObjectIdentifier(Thread.current).hashValue &* 524287)
        for _ in 0..<4
            {
            threadName.append(Character(UnicodeScalar(threadID % 0x55 + 0x13a0)!))
            threadID /= 0x55
            }
        threadName += "]"
        }
    let prefix = "Siesta:\(paddedCategory) │ \(threadName)"
    let indentedMessage = $1.replacingOccurrences(of: "\n", with: "\n" + prefix)
    print(prefix + indentedMessage)
    }

internal func debugLog(_ category: LogCategory, _ messageParts: @autoclosure () -> [Any?])
    {
    if LogCategory.enabled.contains(category)
        { logger(category, debugStr(messageParts())) }
    }
