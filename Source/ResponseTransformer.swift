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
        let pattern = "^" + "|".join(contentTypeRegexps) + "($|;)"
        self.contentTypeMatcher = NSRegularExpression.compile(pattern)
        }

    func process(response: Response) -> Response
        {
        let mimeType: String?
        switch(response)
            {
            case .Success(let entity):
                mimeType = entity.mimeType
            
            case .Failure(let error):
                mimeType = error.entity?.mimeType
            }

        if let mimeType = mimeType where contentTypeMatcher.matches(mimeType)
            {
            debugLog(.ResponseProcessing, [delegate, "matches content type", debugStr(mimeType)])
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
      Subclasses will typically override this method. The default behavior is to leave data unchanged.
     
      Note that overrides can turn a success into an error, e.g. if there is a parse error.
    */
    func processEntity(entity: Entity) -> Response
    
    /**
      Default behavior: attempt to process error response bodies just like success bodies, but if there is a
      transformation error, only log it and preserve the original error.

      Subclasses typically do not override this method, but they can if they wish to apply special processing to errors.
    */
    func processError(error: Error) -> Response
    }

public extension ResponseEntityTransformer
    {
    /// :nodoc:
    final func process(response: Response) -> Response
        {
        switch(response)
            {
            case .Success(let entity):
                return processEntity(entity)
            
            case .Failure(let error):
                return processError(error)
            }
        }
    
    /// :nodoc:
    func processEntity(entity: Entity) -> Response
        { return .Success(entity) }

    /// :nodoc:
    func processError(var error: Error) -> Response
        {
        if let errorData = error.entity
            {
            switch(processEntity(errorData))
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
    /// Utility method to downcast the given entity, or return an error response if the content is not of the given type.
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
