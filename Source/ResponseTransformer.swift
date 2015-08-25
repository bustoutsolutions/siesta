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
  
  Note that transformers run in a GCD background queue, and **must be thread-safe**. You’re in the clear if your
  transformer touches only its input parameter.
*/
public protocol ResponseTransformer
    {
    /**
      Returns the parsed form of this response, or returns it unchanged if this transformer does not apply.
      
      Note that a `Response` can contain either data or an error, so this method can turn success into failure if the
      response fails to parse.
    */
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
  A utility flavor of `ResponseTransformer` that deals only with the response entity (whether success or failure), and
  does not touch the surrounding error metadata (if any).

  To use, implement this protocol and override the `processEntity(_:)` method.
*/
public protocol ResponseEntityTransformer: ResponseTransformer
    {
    /**
      Implementations will typically override this method.
      
      Return `.Success` if the parsing succeeded, `.Failure` if it failed. See the default implementation of
      `processError(_:)` for information about what happens to this method’s return value when the underlying response
      is a failure.
    */
    func processEntity(entity: Entity) -> Response
    
    /**
      Implementations typically do not override this method, but they can if they wish to apply special processing to
      errors. For example, an implementation might want to leave errors untouched, regardless of content type, and only
      apply processing on success.
    */
    func processError(error: Error) -> Response
    }

public extension ResponseEntityTransformer
    {
    /// :nodoc:
    final func process(response: Response) -> Response
        {
        switch response
            {
            case .Success(let entity):
                return processEntity(entity)
            
            case .Failure(let error):
                return processError(error)
            }
        }
    
    /// Returns success with the entity unchanged.
    func processEntity(entity: Entity) -> Response
        { return .Success(entity) }

    /// Attempt to process error’s `content` entity using `processEntity(_:)`. If the processing succeeded, replace the
    /// content of the error. If there was a processing error, log it but preserve the original error.
    func processError(var error: Error) -> Response
        {
        if let errorData = error.entity
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

public extension ResponseTransformer
    {
    /// Utility method to downcast the given entity’s content, or return an error response if the content object is of
    /// the wrong type.
    func requireDataType<T>(
            entity: Entity,
            @noescape process: T -> Response)
        -> Response
        {
        if let typedContent = entity.content as? T
            {
            return process(typedContent)
            }
        else
            {
            return logTransformation(
                .Failure(Error(
                    userMessage: "Cannot parse response",
                    debugMessage: "Expected \(T.self), but got \(entity.content.dynamicType)")))
            }
        }
    }

// MARK: Transformers for standard types

/// Parses an `NSData` content as text, using the encoding specified in the content type, or ISO-8859-1 by default.
public struct TextTransformer: ResponseEntityTransformer
    {
    /// :nodoc:
    public func processEntity(entity: Entity) -> Response
        {
        if entity.content as? String != nil
            {
            debugLog(.ResponseProcessing, [self, "ignoring content because it is already a String"])
            return .Success(entity)
            }
        
        return requireDataType(entity)
            {
            (nsdata: NSData) in
            
            let charsetName = entity.charset ?? "ISO-8859-1"
            let encoding = CFStringConvertEncodingToNSStringEncoding(
                CFStringConvertIANACharSetNameToEncoding(charsetName))
            
            if encoding == UInt(kCFStringEncodingInvalidId)
                {
                return logTransformation(
                    .Failure(Error(
                        userMessage: "Cannot parse text response",
                        debugMessage: "Invalid encoding: \(charsetName)")))
                }
            else if let string = NSString(data: nsdata, encoding: encoding) as? String
                {
                var newEntity = entity
                newEntity.content = string
                return logTransformation(
                    .Success(newEntity))
                }
            else
                {
                return logTransformation(
                    .Failure(Error(
                        userMessage: "Cannot parse text response",
                        debugMessage: "Using encoding: \(charsetName)")))
                }
            }
        }
    }

/// Parses an `NSData` content as JSON, outputting either a dictionary or an array.
public struct JsonTransformer: ResponseEntityTransformer
    {
    /// :nodoc:
    public func processEntity(entity: Entity) -> Response
        {
        return requireDataType(entity)
            {
            (nsdata: NSData) in

            do  {
                var newEntity = entity
                newEntity.content = try NSJSONSerialization.JSONObjectWithData(nsdata, options: [])
                return logTransformation(
                    .Success(newEntity))
                }
            catch
                {
                return logTransformation(
                    .Failure(Error(userMessage: "Cannot parse JSON", error: error as NSError)))
                }
            }
        }
    }
