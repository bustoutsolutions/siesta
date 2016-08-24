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
    case Network

    /// Details of network requests, including headers and bodies.
    case NetworkDetails

    /// Details of how the `ResponseTransformer` parses responses.
    case ResponseProcessing

    /// `ResourceEvent` broadcast by resources.
    case StateChanges

    /// Detailed information about which events are sent to which observers, when they are added, and when they are
    /// removed.
    case Observers

    /// Information about how `Resource.loadIfNeeded()` decides whether to initiate a request.
    case Staleness

    /// Details of when resource data is read from & saved to a persistent cache
    case Cache

    /// Details of which configuration matches which resources, and when it is computed.
    case Configuration

    // MARK: Predefined subsets

    /// A reasonable subset of log categories for normal debugging.
    public static let common: Set<LogCategory> = [Network, StateChanges, Staleness]

    /// Everything except full request/response data.
    public static let detailed = Set<LogCategory>(all.filter { $0 != NetworkDetails})

    /// The whole schebang!
    public static let all: Set<LogCategory> = [Network, NetworkDetails, ResponseProcessing, StateChanges, Observers, Staleness, Cache, Configuration]
    }

/// The set of categories to log. Can be changed at runtime.
public var enabledLogCategories = Set<LogCategory>()

/// Inject your custom logger to do something other than print to stdout.
public var logger: (LogCategory, String) -> Void = { print("[Siesta:\($0.rawValue)] \($1)") }

internal func debugLog(category: LogCategory, @autoclosure _ messageParts: () -> [Any?])
    {
    if enabledLogCategories.contains(category)
        { logger(category, debugStr(messageParts())) }
    }
