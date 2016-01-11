//
//  ResponseTransformer.swift
//  Siesta
//
//  Created by Paul on 2015/7/8.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

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
    @warn_unused_result
    func process(response: Response) -> Response
    }

public extension ResponseTransformer
    {
    /// Helper to log a transformation. Call this in your custom transformer.
    public func logTransformation(result: Response) -> Response
        {
        debugLog(.ResponseProcessing, [self, "→", result])
        return result
        }
    }

// MARK: Chaining

internal struct ContentTypeMatchTransformer: ResponseTransformer
    {
    let contentTypeMatcher: NSRegularExpression
    let delegate: ResponseTransformer

    init(_ delegate: ResponseTransformer, contentTypes: [String])
        {
        self.delegate = delegate

        let contentTypeRegexps = contentTypes.map
            {
            NSRegularExpression.escapedPatternForString($0)
                .stringByReplacingOccurrencesOfString("\\*", withString:"[^/+]+")
            }
        let pattern = "^" + contentTypeRegexps.joinWithSeparator("|") + "($|;)"
        self.contentTypeMatcher = NSRegularExpression.compile(pattern)
        }

    func process(response: Response) -> Response
        {
        let contentType: String?
        switch response
            {
            case .Success(let entity):
                contentType = entity.contentType

            case .Failure(let error):
                contentType = error.entity?.contentType
            }

        if let contentType = contentType where contentTypeMatcher.matches(contentType)
            {
            debugLog(.ResponseProcessing, [delegate, "matches content type", debugStr(contentType)])
            return delegate.process(response)
            }
        else
            { return response }
        }
    }

/**
  A transformer that applies a sequence of transformers to a response, passing the output on one to the input of the
  next. Transformers in the sequence can be limited by content type.

  - SeeAlso: `Service.responseTransformers`
*/
public struct TransformerSequence
    {
    private var transformers = [ResponseTransformer]()

    /// Removes all transformers from this sequence and starts fresh.
    public mutating func clear()
        { transformers.removeAll() }

    /**
      Adds a transformer to the sequence, to apply only if the response matches the given set of content type patterns.
      The content type matches regardles of whether the response is a success or failure.

      Content type patterns can use `*` to match subsequences. The wildcard does not cross `/` or `+` boundaries.
      Examples:

          "text/plain"
          "text/​*"
          "application/​*+json"

      The pattern does not match MIME parameters, so `"text/plain"` matches `"text/plain; charset=utf-8"`.
    */
    public mutating func add(
            transformer: ResponseTransformer,
            contentTypes: [String],
            first: Bool = false)
        {
        add(
            ContentTypeMatchTransformer(transformer, contentTypes: contentTypes),
            first: first)
        }

    /**
      Adds a transformer to the sequence, either at the end (default) or at the beginning.
    */
    public mutating func add(
            transformer: ResponseTransformer,
            first: Bool = false)
        {
        transformers.insert(
            transformer,
            atIndex: first
                ? transformers.startIndex
                : transformers.endIndex)
        }

    /// :nodoc:
    func process(response: Response) -> Response
        {
        return transformers.reduce(response)
            { $1.process($0) }
        }
    }

// MARK: Data transformer plumbing

/**
  A simplified `ResponseTransformer` that deals only with the content of the response entity, and does not touch the
  surrounding metadata.

  If the input entity’s content does not match the `InputContentType`, the response is an error.
  If `processContent(_:)` throws, the response is transformed to an error.
*/
public struct ResponseContentTransformer<InputContentType,OutputContentType>: ResponseTransformer
    {
    /**
      A closure that both processes the content and describes the required input and output types.

      The closure can throw an error to indicate that parsing failed. If it throws a `Siesta.Error`, that
      error is passed on to the resource as is. Other failures are wrapped in a `Siesta.Error`.
    */
    public typealias Processor = (content: InputContentType, entity: Entity) throws -> OutputContentType

    private let processor: Processor
    private let skipWhenEntityMatchesOutputType: Bool
    private let transformErrors: Bool

    /**
      - Parameter skipWhenEntityMatchesOutputType:
          When true, if the input content already matches `OutputContentType`, the transformer does nothing.
          When false, the tranformer always attempts to parse its input.
          Default is true.
      - Parameter transformErrors:
          When true, apply the transformation to `Error.content` (if present).
          When false, only parse success responses.
          Default is false.
      - Parameter processor:
          The transformation logic.
    */
    public init(
            skipWhenEntityMatchesOutputType: Bool = true,
            transformErrors: Bool = false,
            processor: Processor)
        {
        self.skipWhenEntityMatchesOutputType = skipWhenEntityMatchesOutputType
        self.transformErrors = transformErrors
        self.processor = processor
        }

    /// :nodoc:
    public func process(response: Response) -> Response
        {
        switch response
            {
            case .Success(let entity):
                return processEntity(entity)

            case .Failure(let error):
                return processError(error)
            }
        }

    private func processEntity(entity: Entity) -> Response
        {
        if skipWhenEntityMatchesOutputType && entity.content is OutputContentType
            {
            debugLog(.ResponseProcessing, [self, "ignoring content because it is already a \(OutputContentType.self)"])
            return .Success(entity)
            }

        guard let typedContent = entity.content as? InputContentType else
            {
            return logTransformation(
                .Failure(Error(
                    userMessage: NSLocalizedString("Cannot parse server response", comment: "userMessage"),
                    cause: Error.Cause.WrongTypeInTranformerPipeline(
                        expectedType: debugStr(InputContentType.self),
                        actualType: debugStr(entity.content.dynamicType),
                        transformer: self))))
            }

        do  {
            let result = try processor(content: typedContent, entity: entity)
            var entity = entity
            entity.content = result
            return .Success(entity)
            }
        catch
            {
            let siestaError =
                error as? Error
                ?? Error(
                    userMessage: NSLocalizedString("Cannot parse server response", comment: "userMessage"),
                    cause: error)
            return logTransformation(.Failure(siestaError))
            }
        }

    private func processError(error: Error) -> Response
        {
        var error = error
        if let errorData = error.entity where transformErrors
            {
            switch processEntity(errorData)
                {
                case .Success(let errorDataTransformed):
                    error.entity = errorDataTransformed

                case .Failure(let error):
                    debugLog(.ResponseProcessing, ["Unable to parse error response body; will leave error body unprocessed:", error])
                }
            }
        return .Failure(error)
        }
    }

// MARK: Transformers for standard types

/// Parses `NSData` content as text, using the encoding specified in the content type, or ISO-8859-1 by default.
@warn_unused_result
public func TextResponseTransformer(transformErrors: Bool = true) -> ResponseTransformer
    {
    return ResponseContentTransformer(transformErrors: transformErrors)
        {
        (content: NSData, entity: Entity) throws -> String in

        let charsetName = entity.charset ?? "ISO-8859-1"
        let encoding = CFStringConvertEncodingToNSStringEncoding(
            CFStringConvertIANACharSetNameToEncoding(charsetName))

        guard encoding != UInt(kCFStringEncodingInvalidId) else
            { throw Error.Cause.InvalidTextEncoding(encodingName: charsetName) }

        guard let string = NSString(data: content, encoding: encoding) as? String else
            { throw Error.Cause.UndecodableText(encodingName: charsetName) }

        return string
        }
    }

/// Parses `NSData` content as JSON, outputting either a dictionary or an array.
@warn_unused_result
public func JSONResponseTransformer(transformErrors: Bool = true) -> ResponseTransformer
    {
    return ResponseContentTransformer(transformErrors: transformErrors)
        {
        (content: NSData, entity: Entity) throws -> NSJSONConvertible in

        let rawObj = try NSJSONSerialization.JSONObjectWithData(content, options: [.AllowFragments])

        guard let jsonObj = rawObj as? NSJSONConvertible else
            { throw Error.Cause.JSONResponseIsNotDictionaryOrArray(actualType: debugStr(rawObj.dynamicType)) }

        return jsonObj
        }
    }

/// Parses `NSData` content as an image, yielding a `UIImage`.
@warn_unused_result
public func ImageResponseTransformer(transformErrors: Bool = false) -> ResponseTransformer
    {
    return ResponseContentTransformer(transformErrors: transformErrors)
        {
        (content: NSData, entity: Entity) throws -> UIImage in

        guard let image = UIImage(data: content) else
            { throw Error.Cause.UnparsableImage() }

        return image
        }
    }

