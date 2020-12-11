//
//  RequestCreation.swift
//  Siesta
//
//  Created by Paul on 2015/12/15.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//
import Foundation

extension Resource
    {
    // MARK: Request Creation Conveniences

    /**
      Convenience method to initiate a request with a body containing arbitrary data.
      - Parameter method: The HTTP method of the request.
      - Parameter data: The body of the request.
      - Parameter contentType: The value for the request’s `Content-Type` header. The priority order is as follows:
          - any content-type set in `Configuration.mutateRequests(...)` overrides
          - any content-type set in `requestMutation`, which overrides
          - this parameter, which overrides
          - any content-type set with `Configuration.headers`.
      - Parameter requestMutation: Allows you to override details fo the HTTP request before it is sent.
          See `request(_:requestMutation:)`.
    */
    public func request(
            _ method:        RequestMethod,
            data:            Data,
            contentType:     String,
            requestMutation: @escaping RequestMutation = { _ in })
        -> Request
        {
        return request(method)
            {
            underlyingRequest in

            underlyingRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
            underlyingRequest.httpBody = data
            requestMutation(&underlyingRequest)
            }
        }

    /**
      Convenience method to initiate a request with a text body.

      If the string cannot be encoded using the given encoding, this methods triggers the `onFailure(...)` request hook
      immediately, without touching the network.

      - Parameter contentType: `text/plain` by default.
      - Parameter encoding: UTF-8 (`NSUTF8StringEncoding`) by default.
    */
    public func request(
            _ method:        RequestMethod,
            text:            String,
            contentType:     String = "text/plain",
            encoding:        String.Encoding = String.Encoding.utf8,
            requestMutation: @escaping RequestMutation = { _ in })
        -> Request
        {
        guard let rawBody = text.data(using: encoding),
              let encodingName =
                  CFStringConvertEncodingToIANACharSetName(
                      CFStringConvertNSStringEncodingToEncoding(
                          encoding.rawValue))
        else
            {
            return Resource.failedRequest(
                returning: RequestError(
                    userMessage: NSLocalizedString("Cannot send request", comment: "userMessage"),
                    cause: RequestError.Cause.UnencodableText(encoding: encoding, text: text)))
            }

        return request(method, data: rawBody, contentType: "\(contentType); charset=\(encodingName)", requestMutation: requestMutation)
        }

    /**
      Convenience method to initiate a request with a JSON body.

      If the `json` cannot be encoded as JSON, e.g. if it is a dictionary with non-JSON-convertible data, this methods
      triggers the `onFailure(...)` request hook immediately, without touching the network.

      - Parameter contentType: `application/json` by default.
    */
    public func request(
            _ method:        RequestMethod,
            json:            JSONConvertible,
            contentType:     String = "application/json",
            requestMutation: @escaping RequestMutation = { _ in })
        -> Request
        {
        guard JSONSerialization.isValidJSONObject(json) else
            {
            return Resource.failedRequest(
                returning: RequestError(
                    userMessage: NSLocalizedString("Cannot send request", comment: "userMessage"),
                    cause: RequestError.Cause.InvalidJSONObject()))
            }

        do  {
            let rawBody = try JSONSerialization.data(withJSONObject: json, options: [])
            return request(method, data: rawBody, contentType: contentType, requestMutation: requestMutation)
            }
        catch
            {
            // Swift doesn’t catch NSInvalidArgumentException, so the isValidJSONObject() method above is necessary
            // to handle the case of non-encodable input. Given that, it's unclear what other circumstances would cause
            // encoding to fail such that dataWithJSONObject() is declared “throws” (radar 21913397, Apple-rejected!),
            // but we catch the exception anyway instead of using try! and crashing.

            return Resource.failedRequest(
                returning: RequestError(
                    userMessage: NSLocalizedString("Cannot send request", comment: "userMessage"),
                    cause: error))
            }
        }

    /**
      Convenience method to initiate a request with URL-encoded parameters in the meesage body.

      This method performs all necessary escaping, and has full Unicode support in both keys and values.

      The content type is `application/x-www-form-urlencoded`.
    */
    public func request(
            _ method:          RequestMethod,
            urlEncoded params: [String:String],
            requestMutation:   @escaping RequestMutation = { _ in })
        -> Request
        {
        func urlEscape(_ string: String) throws -> String
            {
            guard let escaped = string.addingPercentEncoding(withAllowedCharacters: Resource.allowedCharsInURLEncoding) else
                { throw RequestError.Cause.NotURLEncodable(offendingString: string) }

            return escaped
            }

        do
            {
            let paramString = try
                params.map { try urlEscape($0.0) + "=" + urlEscape($0.1) }
                      .sorted()
                      .joined(separator: "&")
            return request(method,
                data: paramString.data(using: String.Encoding.ascii)
                    .forceUnwrapped(because: "URL-escaped strings are always ASCII-representable"),
                contentType: "application/x-www-form-urlencoded",
                requestMutation: requestMutation)
            }
        catch
            {
            return Resource.failedRequest(
                returning: RequestError(
                    userMessage: NSLocalizedString("Cannot send request", comment: "userMessage"),
                    cause: error))
            }
        }

    private static let allowedCharsInURLEncoding: CharacterSet =
        {
        // Based on https://github.com/Alamofire/Alamofire/blob/338955a54722dea6051ed5c5c76a8736f4195515/Source/ParameterEncoding.swift#L186
        let charsToEscape = ":#[]@!$&'()*+,;="
        var allowedChars = CharacterSet.urlQueryAllowed
        allowedChars.remove(charactersIn: charsToEscape)
        return allowedChars
        }()

    /**
      Convenience method to initiate a request using multipart encoding in the message body.

      Based on code suggested by @Alex293 in https://github.com/bustoutsolutions/siesta/issues/190

      This convenience method just structures @Alex293’s example in a way that parallels the other convenience
      methods in this extension.

      The parameters have the following meanings:
      - values: [String:String] listing the names of various parts and their corresponding values
      - files: optional [String:FilePart] listing the the names of _files_ to upload, with the files represented via a helper FilePart struct (defined at the bottom of this source file)
      - order: optional [String] containing the keys from `values` and `files`—this comes into play if the server or service that accepts multipart requests also requires the parts in a particular order (e.g., S3 wants the `key` part first). The `order` array specifies the order to how the parts are sent. If `order` is not given, then the parts are enumerated in the order that Swift enumerates the keys of the `values` and `files` dictionaries (`values` enumerated first, then `files`)
      - requestMutation: same closure as in the other convenience methods
    */
    public func request(
            _ method: RequestMethod,
            multipart values: [String:String],
            files: [String:FilePart]?,
            order: [String]?,
            requestMutation: @escaping RequestMutation = { _ in })
        -> Request
        {
        func getNames() -> [String]
            {
            if let givenOrder = order {
                return givenOrder
            }

            var names = Array(values.keys)
            if files != nil {
                names.append(contentsOf: files!.keys)
            }

            return names
            }

        func append(_ body: NSMutableData, _ line: String)
            {
            body.append(line.data(using: .utf8)!)
            }

        // Derived from https://github.com/bustoutsolutions/siesta/issues/190#issuecomment-294267686
        let boundary = "Boundary-\(NSUUID().uuidString)"
        let contentType = "multipart/form-data; boundary=\(boundary)"
        let body = NSMutableData()
        let names = getNames()
        names.forEach
            { name in
            append(body, "--\(boundary)\r\n")
            if values.keys.contains(name), let value = values[name]
                {
                append(body, "Content-Disposition:form-data; name=\"\(name)\"\r\n\r\n")
                append(body, "\(value)\r\n")
                }
            else if let givenFiles = files, givenFiles.keys.contains(name), let filePart = givenFiles[name]
                {
                append(body, "Content-Disposition:form-data; name=\"\(name)\"; filename=\"\(filePart.filename)\"\r\n")
                append(body, "Content-Type: \(filePart.type)\r\n\r\n")
                body.append(filePart.data)
                append(body, "\r\n")
                }
            }

        append(body, "--\(boundary)--\r\n")
        return request(method, data: body as Data, contentType: contentType, requestMutation: requestMutation)
        }
    }

/// Dictionaries and arrays can both be passed to `Resource.request(_:json:contentType:requestMutation:)`.
public protocol JSONConvertible { }
extension NSDictionary: JSONConvertible { }
extension NSArray:      JSONConvertible { }
extension Dictionary:   JSONConvertible { }
extension Array:        JSONConvertible { }

/// Helper struct for specifying a file to upload for `Resource.request(_:multipart:files:order:requestMutation:)`.
public struct FilePart
    {
    let filename: String
    let type: String
    let data: Data

    init(filename: String, type: String, data: Data)
        {
        self.filename = filename
        self.type = type
        self.data = data
        }
    }
