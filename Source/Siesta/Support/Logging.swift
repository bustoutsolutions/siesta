//
//  Logging.swift
//  Siesta
//
//  Created by Paul on 2015/7/14.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

/// Namespace for Siesta’s logging API.
public enum SiestaLog
    {
    /**
      Controls which message Siesta will log. See `enabledLogCategories`.

      - SeeAlso: [Logging Guide](https://github.com/bustoutsolutions/siesta/blob/master/Docs/logging.md)
    */
    public enum Category
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

        // MARK: Configuring logging

        /// The set of categories to log. Can be changed at runtime.
        public static var enabled = Set<Category>()

        // MARK: Predefined subsets

        /// A reasonable subset of log categories for normal debugging.
        public static let common: Set<Category> = [network, stateChanges, staleness]

        /// Everything except full request/response data.
        public static let detailed = all.subtracting([networkDetails])

        /// The whole schebang!
        public static let all: Set<Category> = [network, networkDetails, pipeline, stateChanges, observers, staleness, cache, configuration]
        }

    private static let maxCategoryNameLength = Category.all.map { Int(String(describing: $0).count) }.max() ?? 0

    /// Inject your custom logger to do something other than print to stdout.
    public static var messageHandler: (Category, String) -> Void =
        {
        let paddedCategory = String(describing: $0).padding(toLength: maxCategoryNameLength, withPad: " ", startingAt: 0)
        var threadName = ""
        if !Thread.isMainThread
            {
            threadName += "[thread "
            var threadID = abs(ObjectIdentifier(Thread.current).hashValue &* 524287)
            for _ in 0..<4
                {
                threadName.append(Character(
                    UnicodeScalar(threadID % 0x55 + 0x13a0)
                        .forceUnwrapped(because: "Modulus always maps thread IDs to valid unicode scalars")))
                threadID /= 0x55
                }
            threadName += "]"
            }
        let prefix = "Siesta:\(paddedCategory) │ \(threadName)"
        let indentedMessage = $1.replacingOccurrences(of: "\n", with: "\n" + prefix)
        print(prefix + indentedMessage)
        }

    /// Neatly formats `messageParts` as a message, and logs it to `messageHandler` if `category` is enabled.
    public static func log(_ category: Category, _ messageParts: @autoclosure () -> [Any?])
        {
        if Category.enabled.contains(category)
            { messageHandler(category, debugStr(messageParts())) }
        }
    }

// These allow `SiestaLog.Category.enabled = .common` instead of `SiestaLog.Category.enabled = SiestaLog.Category.common`.
extension Set where Element == SiestaLog.Category
    {
    /// A reasonable subset of log categories for normal debugging.
    public static let common = SiestaLog.Category.common

    /// Everything except full request/response data.
    public static let detailed = SiestaLog.Category.detailed

    /// The whole kit and caboodle!
    public static let all = SiestaLog.Category.all
    }
