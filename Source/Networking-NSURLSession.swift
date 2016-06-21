//
//  Networking-NSURLSession.swift
//  Siesta
//
//  Created by Paul on 2015/6/26.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

/**
  Uses `NSURLSessionDataTask` for Siesta networking.

  This is Siesta’s default networking provider.
*/
public struct NSURLSessionProvider: NetworkingProvider
    {
    /// Session which will create `NSURLSessionDataTask`s.
    public let session: NSURLSession

    /// :nodoc:
    public init(session: NSURLSession)
        { self.session = session }

    /// :nodoc:
    public func startRequest(
            request: NSURLRequest,
            completion: RequestNetworkingCompletionCallback)
        -> RequestNetworking
        {
        let task = self.session.dataTaskWithRequest(request)
            { completion(nsres: $1 as? NSHTTPURLResponse, body: $0, error: $2) }
        return NSURLSessionRequestNetworking(task: task)
        }
    }

internal struct NSURLSessionRequestNetworking: RequestNetworking, SessionTaskContainer
    {
    var task: NSURLSessionTask

    private init(task: NSURLSessionDataTask)
        {
        self.task = task
        task.resume()
        }

    func cancel()
        { task.cancel() }
    }

extension NSURLSession: NetworkingProviderConvertible
    {
    /// You can pass an `NSURLSession` when creating a `Service`.
    public var siestaNetworkingProvider: NetworkingProvider
        { return NSURLSessionProvider(session: self) }
    }

extension NSURLSessionConfiguration: NetworkingProviderConvertible
    {
    /// You can pass an `NSURLSessionConfiguration` when creating a `Service`.
    public var siestaNetworkingProvider: NetworkingProvider
        { return NSURLSession(configuration: self).siestaNetworkingProvider }
    }

/// Convenience for `NetworkingProvider` implementations that ultimate rely on an `NSURLSessionTask`.
public protocol SessionTaskContainer
    {
    /// Underlying networking task that can report request progress.
    var task: NSURLSessionTask { get }
    }

public extension SessionTaskContainer
    {
    /// Extracts transfer metrics using bytes counts from `NSURLSessionTask`.
    var transferMetrics: RequestTransferMetrics
        {
        return RequestTransferMetrics(
            requestBytesSent:      task.countOfBytesSent,
            requestBytesTotal:     task.countOfBytesExpectedToSend,
            responseBytesReceived: task.countOfBytesReceived,
            responseBytesTotal:    task.countOfBytesExpectedToReceive)
        }
    }
