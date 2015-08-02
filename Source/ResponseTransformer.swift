//
//  ResponseTransformer.swift
//  Siesta
//
//  Created by Paul on 2015/7/8.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

public protocol ResponseTransformer
    {
    func process(response: Response) -> Response
    }

public extension ResponseTransformer
    {
    func logTransformation(result: Response) -> Response
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
            case .Success(let data):
                mimeType = data.mimeType
            
            case .Failure(let error):
                mimeType = error.data?.mimeType
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

public class TransformerSequence
    {
    private var transformers = [ResponseTransformer]()
    
    public func clear()
        { transformers.removeAll() }
    
    public func add(
            transformer: ResponseTransformer,
            contentTypes: [String],
            first: Bool = false)
        -> Self
        {
        return add(
            ContentTypeMatchTransformer(transformer, contentTypes: contentTypes),
            first: first)
        }
    
    public func add(
            transformer: ResponseTransformer,
            first: Bool = false)
        -> Self
        {
        transformers.insert(
            transformer,
            atIndex: first
                ? transformers.startIndex
                : transformers.endIndex)
        return self
        }

    func process(response: Response) -> Response
        {
        return transformers.reduce(response)
            { $1.process($0) }
        }
    }

// MARK: Data transformer plumbing

public protocol ResponseDataTransformer: ResponseTransformer
    {
    func processData(data: ResourceData) -> Response
    
    func processError(error: ResourceError) -> Response
    }

public extension ResponseDataTransformer
    {
    final func process(response: Response) -> Response
        {
        switch(response)
            {
            case .Success(let data):
                return processData(data)
            
            case .Failure(let error):
                return processError(error)
            }
        }
    
    /// Subclasses will typically override this method. Default is to leave data unchanged.
    ///
    /// Note that overrides can turn a success into an error, e.g. if there is a parse error.
    ///
    func processData(data: ResourceData) -> Response
        { return .Success(data) }

    /// Default behavior: attempt to process error response bodies just like success bodies, but
    /// if there is a transformation error, only log it and preserve the original error.
    ///
    func processError(var error: ResourceError) -> Response
        {
        if let errorData = error.data
            {
            switch(processData(errorData))
                {
                case .Success(let errorDataTransformed):
                    error.data = errorDataTransformed
                
                case .Failure(let error):
                    debugLog(.ResponseProcessing, ["Unable to parse error response body; will leave error body unprocessed:", error])
                }
            }
        return .Failure(error)
        }
    }

public extension ResponseTransformer
    {
    func requireDataType<T>(
            data: ResourceData,
            @noescape process: T -> Response)
        -> Response
        {
        if let typedData = data.payload as? T
            {
            return process(typedData)
            }
        else
            {
            return logTransformation(
                .Failure(ResourceError(
                    userMessage: "Cannot parse response",
                    debugMessage: "Expected \(T.self), but got \(data.payload.dynamicType)")))
            }
        }
    }

// MARK: Transformers for standard types

public struct TextTransformer: ResponseDataTransformer
    {
    public func processData(data: ResourceData) -> Response
        {
        if data.payload as? String != nil
            {
            debugLog(.ResponseProcessing, [self, "ignoring payload because it is already a String"])
            return .Success(data)
            }
        
        return requireDataType(data)
            {
            (nsdata: NSData) in
            
            let charsetName = data.charset ?? "ISO-8859-1"
            let encoding = CFStringConvertEncodingToNSStringEncoding(
                CFStringConvertIANACharSetNameToEncoding(charsetName))
            
            if encoding == UInt(kCFStringEncodingInvalidId)
                {
                return logTransformation(
                    .Failure(ResourceError(
                        userMessage: "Cannot parse text response",
                        debugMessage: "Invalid encoding: \(charsetName)")))
                }
            else if let string = NSString(data: nsdata, encoding: encoding) as? String
                {
                var newData = data
                newData.payload = string
                return logTransformation(
                    .Success(newData))
                }
            else
                {
                return logTransformation(
                    .Failure(ResourceError(
                        userMessage: "Cannot parse text response",
                        debugMessage: "Using encoding: \(charsetName)")))
                }
            }
        }
    }

public struct JsonTransformer: ResponseDataTransformer
    {
    public func processData(data: ResourceData) -> Response
        {
        return requireDataType(data)
            {
            (nsdata: NSData) in

            do  {
                var newData = data
                newData.payload = try NSJSONSerialization.JSONObjectWithData(nsdata, options: [])
                return logTransformation(
                    .Success(newData))
                }
            catch
                {
                return logTransformation(
                    .Failure(ResourceError(userMessage: "Cannot parse JSON", error: error as NSError)))
                }
            }
        }
    }
