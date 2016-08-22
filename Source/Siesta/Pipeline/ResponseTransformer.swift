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

#elseif os(iOS)
    import UIKit

    public typealias Image = UIImage
#endif

/**
  Transforms a response from a less parsed form (e.g. `NSData`) to a more parsed data structure. Responses pass through
  a chain of transformers before being sent to response hooks or observers.

  - Warning: Transformers run in a GCD background queue, and **must be thread-safe**. You’re in the clear if your
             transformer touches only its input parameters, and those parameters are value types or otherwise
             exclusively owned.
*/
public protocol ResponseTransformer
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
    /// Helper to log a transformation. Call this in your custom transformer.
    public func logTransformation(_ result: Response) -> Response
        {
        debugLog(.ResponseProcessing, ["Applied transformer:", self, "\n    → ", result])
        return result
        }
    }

// MARK: Wrapper types

internal struct ContentTypeMatchTransformer: ResponseTransformer
    {
    let contentTypeMatcher: NSRegularExpression
    let delegate: ResponseTransformer

    init(_ delegate: ResponseTransformer, contentTypes: [String])
        {
        self.delegate = delegate

        let contentTypeRegexps = contentTypes.map
            {
            NSRegularExpression.escapedPattern(for: $0)
                .replacingOccurrences(of: "\\*", with:"[^/+]+")
            }
        let pattern = "^" + contentTypeRegexps.joined(separator: "|") + "($|;)"
        self.contentTypeMatcher = NSRegularExpression.compile(pattern)
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

        if let contentType = contentType , contentTypeMatcher.matches(contentType)
            {
            debugLog(.ResponseProcessing, [delegate, "matches content type", debugStr(contentType)])
            return delegate.process(response)
            }
        else
            { return response }
        }
    }

/**
  A simplified `ResponseTransformer` that deals only with the content of the response entity, and does not touch the
  surrounding metadata.

  If `processContent(_:)` throws or returns nil, the output is an error.

  If the input entity’s content does not match the `InputContentType`, the response is an error.
*/
public struct ResponseContentTransformer<InputContentType,OutputContentType>: ResponseTransformer
    {
    /**
      A closure that both processes the content and describes the required input and output types.

      The closure can throw an error to indicate that parsing failed. If it throws a `Siesta.Error`, that
      error is passed on to the resource as is. Other failures are wrapped in a `Siesta.Error`.
    */
    public typealias Processor = (_ content: InputContentType, _ entity: Entity) throws -> OutputContentType?

    private let processor: Processor
    private let mismatchAction: InputTypeMismatchAction
    private let transformErrors: Bool

    /**
      - Parameter mismatchAction:
          Determines what happens when the actual content coming down the pipeline doesn’t match `InputContentType`.
          See `InputTypeMismatchAction` for options. The default is `.Error`.
      - Parameter transformErrors:
          When true, apply the transformation to `Error.content` (if present).
          When false, only parse success responses.
          Default is false.
      - Parameter processor:
          The transformation logic.
    */
    public init(
            onInputTypeMismatch mismatchAction: InputTypeMismatchAction = .error,
            transformErrors: Bool = false,
            processor: Processor)
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
                return logTransformation(processEntity(entity))

            case .failure(let error):
                return logTransformation(processError(error))
            }
        }

    private func processEntity(_ entity: Entity) -> Response
        {
        guard let typedContent = entity.content as? InputContentType else
            {
            switch(mismatchAction)
                {
                case .skip,
                     .skipIfOutputTypeMatches where entity.content is OutputContentType:

                    debugLog(.ResponseProcessing, [self, "skipping transformer because its mismatch rule is", mismatchAction, ", and it expected content of type", InputContentType.self, "but got a", type(of: entity.content)])
                    return .success(entity)

                case .error, .skipIfOutputTypeMatches:
                    return contentTypeMismatchError(entity)
                }
            }

        do  {
            guard let result = try processor(typedContent, entity) else
                { throw Error.Cause.TransformerReturnedNil(transformer: self) }
            var entity = entity
            entity.content = result
            return .success(entity)
            }
        catch
            {
            let siestaError =
                error as? Error
                ?? Error(
                    userMessage: NSLocalizedString("Cannot parse server response", comment: "userMessage"),
                    cause: error)
            return .failure(siestaError)
            }
        }

    private func contentTypeMismatchError(_ entityFromUpstream: Entity) -> Response
        {
        return .failure(Error(
            userMessage: NSLocalizedString("Cannot parse server response", comment: "userMessage"),
            cause: Error.Cause.WrongInputTypeInTranformerPipeline(
                expectedType: debugStr(InputContentType.self),
                actualType: debugStr(type(of: entityFromUpstream.content)),
                transformer: self)))
        }

    private func processError(_ error: Error) -> Response
        {
        var error = error
        if let errorData = error.entity , transformErrors
            {
            switch processEntity(errorData)
                {
                case .success(let errorDataTransformed):
                    error.entity = errorDataTransformed

                case .failure(let error):
                    debugLog(.ResponseProcessing, ["Unable to parse error response body; will leave error body unprocessed:", error])
                }
            }
        return .failure(error)
        }
    }

/**
  Action to take when actual input type at runtime does not match expected input type declared in code.

  - See: `ResponseContentTransformer.init(...)`
  - See: `Service.configureTransformer(...)`
*/
public enum InputTypeMismatchAction
    {
    /// Output `Error.Cause.WrongInputTypeInTranformerPipeline`.
    case error

    /// Pass the input response through unmodified.
    case skip

    /// Pass the input response through unmodified if it matches the output type; otherwise output an error.
    case skipIfOutputTypeMatches
    }


// MARK: Transformers for standard types

/// Parses `NSData` content as text, using the encoding specified in the content type, or ISO-8859-1 by default.
public func TextResponseTransformer(_ transformErrors: Bool = true) -> ResponseTransformer
    {
    return ResponseContentTransformer(transformErrors: transformErrors)
        {
        (content: Data, entity: Entity) throws -> String in

        let charsetName = entity.charset ?? "ISO-8859-1"
        let encoding = CFStringConvertEncodingToNSStringEncoding(
            CFStringConvertIANACharSetNameToEncoding(
                charsetName as NSString as CFString))  // TODO: See if double “as” still necessary in Swift 3 GM

        guard encoding != UInt(kCFStringEncodingInvalidId) else
            { throw Error.Cause.InvalidTextEncoding(encodingName: charsetName) }

        guard let string = NSString(data: content, encoding: encoding) as? String else
            { throw Error.Cause.UndecodableText(encodingName: charsetName) }

        return string
        }
    }

/// Parses `NSData` content as JSON, outputting either a dictionary or an array.
public func JSONResponseTransformer(_ transformErrors: Bool = true) -> ResponseTransformer
    {
    return ResponseContentTransformer(transformErrors: transformErrors)
        {
        (content: Data, entity: Entity) throws -> NSJSONConvertible in

        let rawObj = try JSONSerialization.jsonObject(with: content, options: [.allowFragments])

        guard let jsonObj = rawObj as? NSJSONConvertible else
            { throw Error.Cause.JSONResponseIsNotDictionaryOrArray(actualType: debugStr(type(of: rawObj))) }

        return jsonObj
        }
    }

/// Parses `NSData` content as an image, yielding a `UIImage`.
public func ImageResponseTransformer(_ transformErrors: Bool = false) -> ResponseTransformer
    {
    return ResponseContentTransformer(transformErrors: transformErrors)
        {
        (content: Data, entity: Entity) throws -> Image in

        guard let image = Image(data: content) else
            { throw Error.Cause.UnparsableImage() }

        return image
        }
    }

