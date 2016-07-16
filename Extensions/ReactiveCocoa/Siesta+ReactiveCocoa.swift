//
//  Siesta+ReactiveCocoa.swift
//  Siesta
//
//  Created by Ahmet Karalar on 15/07/16.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation
import Siesta
import ReactiveCocoa
import Result

public struct ResourceState
    {
    public var data: Entity?
    public var error: Error?
    public var isLoading, isRequesting: Bool
    }

public extension Resource
    {
    var state: ResourceState
        {
        return ResourceState(
            data: latestData,
            error: latestError,
            isLoading: isLoading,
            isRequesting: isRequesting)

        }
    }

public struct ReactiveObserver
    {
    public let signal: Signal<ResourceState, NoError>
    private let observer: Observer<ResourceState, NoError>

    public init()
        {
        (signal, observer) = Signal<ResourceState, NoError>.pipe()
        }
    }

extension ReactiveObserver: ResourceObserver
    {
    public func resourceChanged(resource: Resource, event: ResourceEvent)
        {
        observer.sendNext(resource.state)
        }
    }

public extension Resource
    {

    public func rac_signal(
            owner: AnyObject)
        -> Signal<ResourceState, NoError>
        {
        let reactiveObserver = ReactiveObserver()
        self.addObserver(reactiveObserver, owner: owner)
        return reactiveObserver.signal
        }
    
    public func rac_request(
            method: RequestMethod,
            @noescape requestMutation: NSMutableURLRequest -> () = { _ in })
        -> SignalProducer<Entity, Error>
        {
        let nsreq = nsreqWith(method, requestMutation: requestMutation)
        return SignalProducer
            {
            [weak self] observer, disposable in
            
            let req = self!.requestWith(nsreq)
                .onSuccess
                    {
                    entity in
                    observer.sendNext(entity)
                    observer.sendCompleted()
                    }
                .onFailure
                    {
                    error in
                    observer.sendFailed(error)
                    }

            disposable.addDisposable
                {
                req.cancel()
                }
            }
        }
    }

// MARK - Request Creation Convenience

public extension Resource {
    public func rac_request(
            method: RequestMethod,
            data: NSData,
            contentType: String,
            @noescape requestMutation: NSMutableURLRequest -> () = { _ in })
        -> SignalProducer<Entity, Error>
        {
        return rac_request(method)
            {
            nsreq in
            nsreq.addValue(contentType, forHTTPHeaderField: "Content-Type")
            nsreq.HTTPBody = data
                
            requestMutation(nsreq)
            }
        }

    public func rac_request(
            method: RequestMethod,
            text: String,
            contentType: String = "text/plain",
            encoding: NSStringEncoding = NSUTF8StringEncoding,
            @noescape requestMutation: NSMutableURLRequest -> () = { _ in })
        -> SignalProducer<Entity, Error>
        {
        let encodingName = CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(encoding))
        guard let rawBody = text.dataUsingEncoding(encoding) else
            {
            return SignalProducer(
                error: Error(
                    userMessage: NSLocalizedString("Cannot send request", comment: "userMessage"),
                    cause: Error.Cause.UnencodableText(encodingName: encodingName as String,
                                                       text: text)))
            }

        return rac_request(method,
                           data: rawBody,
                           contentType: "\(contentType); charset=\(encodingName)")
        }

    public func rac_request(
            method: RequestMethod,
            json: NSJSONConvertible,
            contentType: String = "application/json",
            @noescape requestMutation: NSMutableURLRequest -> () = { _ in })
        -> SignalProducer<Entity, Error>
        {
        guard NSJSONSerialization.isValidJSONObject(json) else
            {
            return SignalProducer(
                error: Error(
                    userMessage: NSLocalizedString("Cannot send request", comment: "userMessage"),
                    cause: Error.Cause.InvalidJSONObject()))
            }

        do  {
            let rawBody = try NSJSONSerialization.dataWithJSONObject(json, options: [])
            return rac_request(method, data: rawBody, contentType: contentType)
            }
        catch
            {
            // Swift doesn’t catch NSInvalidArgumentException, so the isValidJSONObject() method above is necessary
            // to handle the case of non-encodable input. Given that, it's unclear what other circumstances would cause
            // encoding to fail such that dataWithJSONObject() is declared “throws” (radar 21913397, Apple-rejected!),
            // but we catch the exception anyway instead of using try! and crashing.

            return SignalProducer(
                error: Error(
                    userMessage: NSLocalizedString("Cannot send request", comment: "userMessage"),
                    cause: error))
            }

        }

    public func rac_request(
            method: RequestMethod,
            urlEncoded params: [String:String],
            requestMutation: NSMutableURLRequest -> () = { _ in })
        -> SignalProducer<Entity, Error>
        {
        func urlEscape(string: String) throws -> String
            {
            guard let escaped = string.stringByAddingPercentEncodingWithAllowedCharacters(Resource.allowedCharsInURLEncoding) else
                {
                throw Error.Cause.NotURLEncodable(offendingString: string)
                }

            return escaped
            }

        do  {
            let paramString = try
            params.map { try urlEscape($0.0) + "=" + urlEscape($0.1) }
                  .sort()
                  .joinWithSeparator("&")
            return rac_request(method,
                               data: paramString.dataUsingEncoding(NSASCIIStringEncoding)!,  // Reason for !: ASCII guaranteed safe because of escaping
                               contentType: "application/x-www-form-urlencoded")
            }
        catch
            {
            return SignalProducer(
                error: Error(
                    userMessage: NSLocalizedString("Cannot send request", comment: "userMessage"),
                    cause: error))
            }
        }

    private static let allowedCharsInURLEncoding: NSCharacterSet =
        {
            // Based on https://github.com/Alamofire/Alamofire/blob/338955a54722dea6051ed5c5c76a8736f4195515/Source/ParameterEncoding.swift#L186
            let charsToEscape = ":#[]@!$&'()*+,;="
            let allowedChars = NSCharacterSet.URLQueryAllowedCharacterSet().mutableCopy()
                as! NSMutableCharacterSet  // Reason for !: No typesafe NSMutableCharacterSet copy constructor
            allowedChars.removeCharactersInString(charsToEscape)
            return allowedChars
        }()
}
