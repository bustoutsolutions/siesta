//
//  ConfigurationPatternConvertible.swift
//  Siesta
//
//  Created by Paul on 2016/4/22.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation


/**
  A type that can serve as a URL matcher for service configuration.

  Siesta provides implementations of this protocol for `String` (for glob-based matching) and `Resource` (to configure
  one specific resource).

  - SeeAlso: `Service.configure(...)`
  - SeeAlso: `String.configurationPattern(for:)`
  - SeeAlso: `Resource.configurationPattern(for:)`
*/
public protocol ConfigurationPatternConvertible
    {
    /// Turns the receiver into a predicate that matches URLs.
    func configurationPattern(for service: Service) -> (URL) -> Bool

    /// A logging-friendly description of the receiver when it acts as a URL pattern.
    var configurationPatternDescription: String { get }
    }

/**
  Support for passing URL patterns with wildcards to `Service.configure(...)`.
*/
extension String: ConfigurationPatternConvertible
    {
    /**
      Matches URLs using shell-like wildcards / globs.

      The `urlPattern` is interpreted relative to the service’s base URL unless it begins with a protocol (e.g. `http:`).
      If it is relative, the leading slash is optional.

      The pattern supports three wildcards:

      - `*` matches zero or more characters within a path segment.
      - `**` matches zero or more characters across path segments, with the special case that `/​**​/` matches `/`.
      - `?` matches exactly one character within a path segment, and thus `?*` matches one or more.

      Examples:

      - `/foo/​*​/bar` matches `/foo/1/bar` and `/foo/123/bar`.
      - `/foo/​**​/bar` matches `/foo/bar`, `/foo/123/bar`, and `/foo/1/2/3/bar`.
      - `/foo*​/bar` matches `/foo/bar` and `/food/bar`.
      - `/foo/​​*` matches `/foo/123` and `/foo/`.
      - `/foo/?*` matches `/foo/123` but _not_ `/foo/`.

      The pattern ignores the resource’s query string.
    */
    public func configurationPattern(for service: Service) -> (URL) -> Bool
        {
        // If the pattern has a URL protocol (e.g. "http:"), interpret it as absolute.
        // If the service has no baseURL, interpret the pattern as absolute.
        // Otherwise, interpret pattern as relative to baseURL.

        let resolvedPattern: String
        if !contains(regex: "^[a-z]+:"), let prefix = service.baseURL?.absoluteString
            { resolvedPattern = prefix + stripPrefix("/") }
        else
            { resolvedPattern = self }

        let pattern = try! NSRegularExpression(pattern:
            "^"
            + NSRegularExpression.escapedPattern(for: resolvedPattern)
                .replacingOccurrences(of: "\\*\\*\\/", with: "([^?]*/|)")
                .replacingOccurrences(of: "\\*\\*",    with: "[^?]*")
                .replacingOccurrences(of: "\\*",       with: "[^/?]*")
                .replacingOccurrences(of: "\\?",       with: "[^/?]")
            + "($|\\?)")
        debugLog(.configuration, ["URL pattern", self, "compiles to regex", pattern.pattern])

        return pattern.configurationPattern(for: service)
        }

    /// :nodoc:
    public var configurationPatternDescription: String
        { return self }
    }

/**
  Support for passing regular expressions to `Service.configure(...)`.
*/
extension NSRegularExpression: ConfigurationPatternConvertible
    {
    /**
      Matches URLs if this regular expression matches any substring of the URL’s full, absolute form.

      Note that, unlike the simpler wildcard form of `String.configurationPattern(for:)`, the regular expression is _not_
      matched relative to the Service’s base URL. The match is performed against the full URL: scheme, host, path,
      query string and all.

      Note also that this implementation matches substrings. Include `^` and `$` if you want your pattern to match
      against the entire URL.
    */
    public func configurationPattern(for service: Service) -> (URL) -> Bool
        {
        return { self.matches($0.absoluteString) }
        }

    /// :nodoc:
    public var configurationPatternDescription: String
        { return pattern }
    }

/**
  Support for passing a specific `Resource` to `Service.configure(...)`.
*/
extension Resource: ConfigurationPatternConvertible
    {
    /**
      Matches this specific resource when passed as a pattern to `Service.configure(...)`.
    */
    public func configurationPattern(for service: Service) -> (URL) -> Bool
        {
        let resourceURL = url  // prevent resource capture in closure
        return { $0 == resourceURL }
        }

    /// :nodoc:
    public var configurationPatternDescription: String
        { return url.absoluteString }
    }
