//
//  ResponseTransformer.swift
//  Siesta
//
//  Created by Paul on 2015/7/8.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

#if os(OSX)
    import AppKit

    /// A cross-platform alias for the output type of Siesta’s image content transformer.
    /// `UIImage` on iOS; `NSImage` on macOS.
    public typealias Image = NSImage

#elseif os(iOS) || os(tvOS) || os(watchOS)
    import UIKit

    public typealias Image = UIImage
#endif

/**
  Transforms a response from a less parsed form (e.g. `Data`) to a more parsed data structure. Responses pass through
  a chain of transformers before being sent to response hooks or observers.

  - Warning: Transformers run in a GCD background queue, and **must be thread-safe**. You’re in the clear if your
             transformer touches only its input parameters, and those parameters are value types or otherwise
             exclusively owned.
*/
public protocol ResponseTransformer: CustomDebugStringConvertible
    {
    /**
      Returns the parsed form of this response, or returns it unchanged if this transformer does not apply.

      Note that a `Response` can contain either data or an error, so this method can turn success into failure if the
      response fails to parse.
    */
    func process(_ response: Response) -> Response
    }

public extension ResponseTransformer
    {
    /// Prints the name of the transformer’s Swift type.
    public var debugDescription: String
        { return String(describing: type(of: self)) }

    /// Helper to log a transformation. Call this in your custom transformer.
    public func logTransformation(_ result: Response) -> Response
        {
        debugLog(.pipeline, ["  ├╴Applied transformer:", self, "\n  │ ↳", result.summary()])
        return result
        }
    }

// MARK: Wrapper types

internal struct ContentTypeMatchTransformer: ResponseTransformer
    {
    let contentTypes: [String]  // for logging
    let contentTypeMatcher: NSRegularExpression
    let delegate: ResponseTransformer

    init(_ delegate: ResponseTransformer, contentTypes: [String])
        {
        self.delegate = delegate
        self.contentTypes = contentTypes

        let contentTypeRegexps = contentTypes.map
            {
            NSRegularExpression.escapedPattern(for: $0)
                .replacingOccurrences(of: "\\*", with:"[^/+]+")
            }
        let pattern = "^" + contentTypeRegexps.joined(separator: "|") + "($|;)"
        self.contentTypeMatcher = try! NSRegularExpression(pattern: pattern)
        }

    func process(_ response: Response) -> Response
        {
        let contentType: String?
        switch response
            {
            case .success(let entity):
                contentType = entity.contentType

            case .failure(let error):
                contentType = error.entity?.contentType
            }

        if let contentType = contentType,
           contentTypeMatcher.matches(contentType)
            {
            debugLog(.pipeline, ["  ├╴Transformer", self, "matches content type", debugStr(contentType)])
            return delegate.process(response)
            }
        else
            { return response }
        }

    var debugDescription: String
        {
        return "⟨\(contentTypes.joined(separator: " "))⟩ \(delegate)"
        }
    }

/**
  A simplified `ResponseTransformer` that deals only with the content of the response entity, and does not touch the
  surrounding metadata.

  If `processEntity(_:)` throws or returns nil, the output is an error.

  If the input entity’s content does not match the `InputContentType`, the response is an error.
*/
public struct ResponseContentTransformer<InputContentType, OutputContentType>: ResponseTransformer
    {
    /**
      A closure that both processes the content and describes the required input and output types.

      The input will be an `Entity` whose `content` is safely cast to the type expected by the closure.
      If the response content is not castable to `InputContentType`, then the pipeline skips the closure
      and replaces the resopnse with a `RequestError` describing the type mismatch.

      The closure can throw an error to indicate that parsing failed. If it throws a `RequestError`, that
      error is passed on to the resource as is. Other failures are wrapped in a `RequestError`.
    */
    public typealias Processor = (Entity<InputContentType>) throws -> OutputContentType?

    private let processor: Processor
    private let mismatchAction: InputTypeMismatchAction
    private let transformErrors: Bool

    /**
      - Parameter mismatchAction:
          Determines what happens when the actual content coming down the pipeline doesn’t match `InputContentType`.
          See `InputTypeMismatchAction` for options. The default is `.error`.
      - Parameter transformErrors:
          When true, apply the transformation to `RequestError.content` (if present).
          When false, only parse success responses.
          Default is false.
      - Parameter processor:
          The transformation logic.
    */
    public init(
            onInputTypeMismatch mismatchAction: InputTypeMismatchAction = .error,
            transformErrors: Bool = false,
            processor: @escaping Processor)
        {
        self.mismatchAction = mismatchAction
        self.transformErrors = transformErrors
        self.processor = processor
        }

    /// :nodoc:
    public func process(_ response: Response) -> Response
        {
        switch response
            {
            case .success(let entity):
                return processEntity(entity)

            case .failure(let error):
                return processError(error)
            }
        }

    private func processEntity(_ entity: Entity<Any>) -> Response
        {
        guard let typedEntity = entity.withContentRetyped() as Entity<InputContentType>? else
            {
            switch mismatchAction
                {
                case .skip,
                     .skipIfOutputTypeMatches where entity.content is OutputContentType:

                    debugLog(.pipeline, [self, "skipping transformer because its mismatch rule is", mismatchAction, ", and it expected content of type", InputContentType.self, "but got a", type(of: entity.content)])
                    return .success(entity)

                case .error,
                     .skipIfOutputTypeMatches:

                    return logTransformation(contentTypeMismatchError(entity))
                }
            }

        do  {
            guard let result = try processor(typedEntity) else
                { throw RequestError.Cause.TransformerReturnedNil(transformer: self) }
            var entity = entity
            entity.content = result
            return logTransformation(.success(entity))
            }
        catch
            {
            let siestaError =
                error as? RequestError
                ?? RequestError(
                    userMessage: NSLocalizedString("Cannot parse server response", comment: "userMessage"),
                    cause: error)
            return logTransformation(.failure(siestaError))
            }
        }

    private func contentTypeMismatchError(_ entityFromUpstream: Entity<Any>) -> Response
        {
        return .failure(RequestError(
            userMessage: NSLocalizedString("Cannot parse server response", comment: "userMessage"),
            cause: RequestError.Cause.WrongInputTypeInTranformerPipeline(
                expectedType: InputContentType.self,
                actualType: type(of: entityFromUpstream.content),
                transformer: self)))
        }

    private func processError(_ error: RequestError) -> Response
        {
        if transformErrors, let errorData = error.entity
            {
            switch processEntity(errorData)
                {
                case .success(let errorDataTransformed):
                    var error = error
                    error.entity = errorDataTransformed
                    return logTransformation(.failure(error))

                case .failure(let error):
                    debugLog(.pipeline, ["Unable to parse error response body; will leave error body unprocessed:", error])
                }
            }
        return .failure(error)
        }

    public var debugDescription: String
        {
        var result = "\(InputContentType.self) → \(OutputContentType.self)"

        var options: [String] = []
        if mismatchAction != .error
            { options.append("mismatchAction: \(mismatchAction)") }
        if transformErrors
            { options.append("transformErrors: \(transformErrors)") }
        if !options.isEmpty
            { result += "  [\(options.joined(separator: ", "))]" }

        return result
        }
    }

/**
  Action to take when actual input type at runtime does not match expected input type declared in code.

  - See: `ResponseContentTransformer.init(...)`
  - See: `Service.configureTransformer(...)`
*/
public enum InputTypeMismatchAction
    {
    /// Output `RequestError.Cause.WrongInputTypeInTranformerPipeline`.
    case error

    /// Pass the input response through unmodified.
    case skip

    /// Pass the input response through unmodified if it matches the output type; otherwise output an error.
    case skipIfOutputTypeMatches
    }


// MARK: Transformers for standard types

/// Parses `Data` content as text, using the encoding specified in the content type, or ISO-8859-1 by default.
public func TextResponseTransformer(_ transformErrors: Bool = true) -> ResponseTransformer
    {
    return ResponseContentTransformer<Data, String>(transformErrors: transformErrors)
        {
        let charsetName = $0.charset ?? "ISO-8859-1"
        let encodingID = CFStringConvertEncodingToNSStringEncoding(
            CFStringConvertIANACharSetNameToEncoding(charsetName as CFString))

        guard encodingID != UInt(kCFStringEncodingInvalidId) else
            { throw RequestError.Cause.InvalidTextEncoding(encodingName: charsetName) }

        let encoding = String.Encoding(rawValue: encodingID)
        guard let string = String(data: $0.content, encoding: encoding) else
            { throw RequestError.Cause.UndecodableText(encoding: encoding) }

        return string
        }
    }

/// Parses `Data` content as JSON, outputting either a dictionary or an array.
public func JSONResponseTransformer(_ transformErrors: Bool = true) -> ResponseTransformer
    {
    return ResponseContentTransformer<Data, JSONConvertible>(transformErrors: transformErrors)
        {
        let rawObj = try JSONSerialization.jsonObject(with: $0.content, options: [.allowFragments])

        guard let jsonObj = rawObj as? JSONConvertible else
            { throw RequestError.Cause.JSONResponseIsNotDictionaryOrArray(actualType: type(of: rawObj)) }

        return jsonObj
        }
    }

/// Parses `Data` content as an image, yielding a `UIImage`.
public func ImageResponseTransformer(_ transformErrors: Bool = false) -> ResponseTransformer
    {
    return ResponseContentTransformer<Data, Image>(transformErrors: transformErrors)
        {
        guard let image = Image(data: $0.content) else
            { throw RequestError.Cause.UnparsableImage() }

        return image
        }
    }
