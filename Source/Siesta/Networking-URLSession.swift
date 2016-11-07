//
//  Networking-URLSession.swift
//  Siesta
//
//  Created by Paul on 2015/6/26.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

/**
  Uses `URLSessionDataTask` for Siesta networking.

  This is Siesta’s default networking provider.
*/
public struct URLSessionProvider: NetworkingProvider
    {
    /// Session which will create `URLSessionDataTask`s.
    public let session: URLSession

    /// :nodoc:
    public init(session: URLSession)
        { self.session = session }

    /// :nodoc:
    public func startRequest(
            _ request: URLRequest,
            completion: @escaping RequestNetworkingCompletionCallback)
        -> RequestNetworking
        {
        let task = self.session.dataTask(with: request)
            { completion($1 as? HTTPURLResponse, $0, $2) }
        return URLSessionRequestNetworking(task: task)
        }
    }

private struct URLSessionRequestNetworking: RequestNetworking, SessionTaskContainer
    {
    var task: URLSessionTask

    fileprivate init(task: URLSessionDataTask)
        {
        self.task = task
        task.resume()
        }

    func cancel()
        { task.cancel() }
    }

extension URLSession: NetworkingProviderConvertible
    {
    /// You can pass an `URLSession` when creating a `Service`.
    public var siestaNetworkingProvider: NetworkingProvider
        { return URLSessionProvider(session: self) }
    }

extension URLSessionConfiguration: NetworkingProviderConvertible
    {
    /// You can pass an `URLSessionConfiguration` when creating a `Service`.
    public var siestaNetworkingProvider: NetworkingProvider
        { return URLSession(configuration: self).siestaNetworkingProvider }
    }

/// Convenience for `NetworkingProvider` implementations that ultimate rely on an `URLSessionTask`.
public protocol SessionTaskContainer
    {
    /// Underlying networking task that can report request progress.
    var task: URLSessionTask { get }
    }

public extension SessionTaskContainer
    {
    /// Extracts transfer metrics using bytes counts from `URLSessionTask`.
    var transferMetrics: RequestTransferMetrics
        {
        return RequestTransferMetrics(
            requestBytesSent:      task.countOfBytesSent,
            requestBytesTotal:     task.countOfBytesExpectedToSend,
            responseBytesReceived: task.countOfBytesReceived,
            responseBytesTotal:    task.countOfBytesExpectedToReceive)
        }
    }
