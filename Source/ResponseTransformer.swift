//
//  ResponseTransformer.swift
//  Siesta
//
//  Created by Paul on 2015/7/8.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

public enum Response: CustomStringConvertible
    {
    case DATA(Resource.Data)
    case ERROR(Resource.Error)
    
    public var description: String
        {
        switch(self)
            {
            case .DATA(let value):  return debugStr(value)
            case .ERROR(let value): return debugStr(value)
            }
        }
    }

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
        switch(response)
            {
            case .DATA(let data):
                if contentTypeMatcher.matches(data.mimeType)
                    {
                    debugLog(.ResponseProcessing, [delegate, "matches content type", debugStr(data.mimeType)])
                    return delegate.process(response)
                    }
                else
                    { return response }
            
            case .ERROR:
                return response
            }
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
    func processData(data: Resource.Data) -> Response
    }

public extension ResponseDataTransformer
    {
    func processData(data: Resource.Data) -> Response
        { return .DATA(data) }

    final func process(response: Response) -> Response
        {
        switch(response)
            {
            case .DATA(let data): return processData(data)
            case .ERROR:          return response
            }
        }
    }

public extension ResponseTransformer
    {
    func requireDataType<T>(
            data: Resource.Data,
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
                .ERROR(Resource.Error(
                    userMessage: "Cannot parse response",
                    debugMessage: "Expected \(T.self), but got \(data.payload.dynamicType)")))
            }
        }
    }

// MARK: Transformers for standard types

public struct TextTransformer: ResponseDataTransformer
    {
    public func processData(data: Resource.Data) -> Response
        {
        if data.payload as? String != nil
            {
            debugLog(.ResponseProcessing, [self, "ignoring payload because it is already a String"])
            return .DATA(data)
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
                    .ERROR(Resource.Error(
                        userMessage: "Cannot parse text response",
                        debugMessage: "Invalid encoding: \(charsetName)")))
                }
            else if let string = NSString(data: nsdata, encoding: encoding) as? String
                {
                var newData = data
                newData.payload = string
                return logTransformation(
                    .DATA(newData))
                }
            else
                {
                return logTransformation(
                    .ERROR(Resource.Error(
                        userMessage: "Cannot parse text response",
                        debugMessage: "Using encoding: \(charsetName)")))
                }
            }
        }
    }

public struct JsonTransformer: ResponseDataTransformer
    {
    public func processData(data: Resource.Data) -> Response
        {
        return requireDataType(data)
            {
            (nsdata: NSData) in

            do  {
                var newData = data
                newData.payload = try NSJSONSerialization.JSONObjectWithData(nsdata, options: [])
                return logTransformation(
                    .DATA(newData))
                }
            catch
                {
                return logTransformation(
                    .ERROR(Resource.Error(userMessage: "Cannot parse JSON", error: error as NSError)))
                }
            }
        }
    }
