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
public enum LogCategory: String
    {
    /// Summary of network requests: HTTP method, URL, and result code.
    case network

    /// Details of network requests, including headers and bodies.
    case networkDetails

    /// Details of how the `ResponseTransformer` parses responses.
    case responseProcessing

    /// `ResourceEvent` broadcast by resources.
    case stateChanges

    /// Detailed information about which events are sent to which observers, when they are added, and when they are
    /// removed.
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
    public static let all: Set<LogCategory> = [network, networkDetails, responseProcessing, stateChanges, observers, staleness, cache, configuration]
    }

/// The set of categories to log. Can be changed at runtime.
public var enabledLogCategories = Set<LogCategory>()

/// Inject your custom logger to do something other than print to stdout.
public var logger: (LogCategory, String) -> Void = { print("[Siesta:\($0.rawValue)] \($1)") }

internal func debugLog(_ category: LogCategory, _ messageParts: @autoclosure () -> [Any?])
    {
    if enabledLogCategories.contains(category)
        { logger(category, debugStr(messageParts())) }
    }
