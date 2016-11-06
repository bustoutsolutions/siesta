//
//  DebugFormatting.swift
//  Siesta
//
//  Created by Paul on 2015/8/18.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

private let whitespacePat = try! NSRegularExpression(pattern: "\\s+")

internal func debugStr(
        _ x: Any?,
        consolidateWhitespace: Bool = false,
        truncate: Int? = 500)
    -> String
    {
    guard let x = x else
        { return "nil" }

    var s: String
    if let debugPrintable = x as? CustomDebugStringConvertible
        { s = debugPrintable.debugDescription }
    else
        { s = "\(x)" }

    if consolidateWhitespace
        { s = s.replacing(regex: whitespacePat, with: " ") }

    if let truncate = truncate, s.characters.count > truncate
        { s = s.substring(to: s.index(s.startIndex, offsetBy: truncate)) + "…" }

    return s
    }

internal func debugStr(
        _ messageParts: [Any?],
        join: String = " ",
        consolidateWhitespace: Bool = true,
        truncate: Int? = 300)
    -> String
    {
    return messageParts
        .map
            {
            ($0 as? String)
                ?? debugStr($0, consolidateWhitespace: consolidateWhitespace, truncate: truncate)
            }
        .joined(separator: " ")
    }

internal func conciseSourceLocation(file: String, line: Int) -> String
    {
    return "\((file as NSString).lastPathComponent):\(line)"
    }

internal func dumpHeaders(_ headers: [String:String], indent: String = "") -> String
    {
    var result = "\n" + indent + "headers (\(headers.count))"

    for (k, v) in headers
        { result += "\n" + indent + "  \(k): \(v)" }

    return result
    }

extension Configuration
    {
    internal func dump(_ indent: String = "") -> String
        {
        return "\n" + indent + "expirationTime:            \(expirationTime) sec"
             + "\n" + indent + "retryTime:                 \(retryTime) sec"
             + "\n" + indent + "progressReportingInterval: \(progressReportingInterval) sec"
             + dumpHeaders(headers, indent: indent)
             + "\n" + indent + "requestDecorators: \(requestDecorators.count)"
             + "\n" + indent + "pipeline"
             + pipeline.dump(indent + "  ")
        }
    }

extension Pipeline
    {
    internal func dump(_ indent: String = "") -> String
        {
        var result = ""
        for stageKey in order
            {
            result += "\n" + indent + "║ " + stageKey.description + " stage"
            let stage = self[stageKey]
            if stage.transformers.isEmpty
                { result += " (no transformers)" }
            for transformer in stage.transformers
                { result += "\n" + indent + "╟   " + debugStr(transformer) }
            if let cacheBox = stage.cacheBox
                { result += "\n" + indent + "╟─→ " + cacheBox.description }
            }
        return result
        }
    }

extension Response
    {
    internal func dump(_ indent: String = "") -> String
        {
        switch self
            {
            case .success(let value): return "\n" + indent + "success" + value.dump(indent + "  ")
            case .failure(let value): return "\n" + indent + "failure" + value.dump(indent + "  ")
            }
        }

    internal func summary() -> String
        {
        let kind: String, payload: String
        switch self
            {
            case .success(let entity): (kind, payload) = ("success", debugStr(entity.content, consolidateWhitespace: true, truncate: 80))
            case .failure(let error):  (kind, payload) = ("failure", error.summary())
            }
        return kind + ": " + payload
        }
    }

extension Entity
    {
    internal func dump(_ indent: String = "") -> String
        {
        return "\n" + indent + "contentType: \(contentType)"
             + "\n" + indent + "charset:     \(debugStr(charset))"
             + dumpHeaders(headers, indent: indent)
             + "\n" + indent + "content: (\(type(of: content)))\n"
             + formattedContent.replacing(regex: "^|\n", with: "$0  " + indent)
        }

    private var formattedContent: String
        {
        if JSONSerialization.isValidJSONObject(content),
           let jsonData = try? JSONSerialization.data(withJSONObject: content, options: [.prettyPrinted]),
           let json = String(data: jsonData, encoding: String.Encoding.utf8)
            { return json }

        return debugStr(content, truncate: Int.max)
        }
    }

extension RequestError
    {
    internal func dump(_ indent: String = "") -> String
        {
        var result = "\n" + indent + "userMessage:    \(debugStr(userMessage, consolidateWhitespace: true, truncate: 80))"
        if httpStatusCode != nil
            { result += "\n" + indent + "httpStatusCode: \(debugStr(httpStatusCode))" }
        if cause != nil
            { result += "\n" + indent + "cause:          \(debugStr(cause, consolidateWhitespace: true))" }
        if let entity = entity
            { result += "\n" + indent + "entity:" + entity.dump(indent + "  ") }
        return result
        }

    internal func summary() -> String
        {
        var result = debugStr(userMessage, truncate: 24)
        if let httpStatusCode = httpStatusCode
            { result += " \(httpStatusCode)" }
        if let content = entity?.content
            { result += " content: \(type(of: content))" }
        if let cause = cause
            { result += " cause: " + debugStr(cause, truncate: 32)}
        return result
        }
    }
