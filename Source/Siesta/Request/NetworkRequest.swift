//
//  NetworkRequest.swift
//  Siesta
//
//  Created by Paul on 2015/12/15.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

internal final class NetworkRequest: RequestWithDefaultCallbacks, CustomDebugStringConvertible
    {
    // Basic metadata
    private let resource: Resource
    private let requestDescription: String
    internal var config: Configuration
        { return resource.configuration(for: underlyingRequest) }

    // Networking
    private let requestBuilder: (Void) -> URLRequest
    private let underlyingRequest: URLRequest
    internal var networking: RequestNetworking?  // present only after start()
    internal var underlyingNetworkRequestCompleted = false  // so tests can wait for it to finish

    // Progress
    private var progressTracker: ProgressTracker
    var progress: Double
        { return progressTracker.progress }

    // Result
    private var responseCallbacks = CallbackGroup<ResponseInfo>()
    private var wasCancelled: Bool = false
    var isCompleted: Bool
        {
        DispatchQueue.mainThreadPrecondition()
        return responseCallbacks.completedValue != nil
        }

    // MARK: Managing request

    init(resource: Resource, requestBuilder: @escaping (Void) -> URLRequest)
        {
        self.resource = resource
        self.requestBuilder = requestBuilder  // for repeated()
        self.underlyingRequest = requestBuilder()
        self.requestDescription =
            LogCategory.enabled.contains(.network) || LogCategory.enabled.contains(.networkDetails)
                ? debugStr([underlyingRequest.httpMethod, underlyingRequest.url])
                : ""

        progressTracker = ProgressTracker(isGet: underlyingRequest.httpMethod == "GET")  // URLRequest automatically uppercases method
        }

    func start() -> Self
        {
        DispatchQueue.mainThreadPrecondition()

        guard self.networking == nil else
            {
            debugLog(.networkDetails, [requestDescription, "already started"])
            return self
            }

        guard !wasCancelled else
            {
            debugLog(.network, [requestDescription, "will not start because it was already cancelled"])
            underlyingNetworkRequestCompleted = true
            return self
            }

        debugLog(.network, [requestDescription])

        let networking = resource.service.networkingProvider.startRequest(underlyingRequest)
            {
            res, data, err in
            DispatchQueue.main.async
                { self.responseReceived(underlyingResponse: res, body: data, error: err) }
            }
        self.networking = networking

        progressTracker.start(
            networking,
            reportingInterval: config.progressReportingInterval)

        return self
        }

    func cancel()
        {
        DispatchQueue.mainThreadPrecondition()

        guard !isCompleted else
            {
            debugLog(.network, ["cancel() called but request already completed:", requestDescription])
            return
            }

        debugLog(.network, ["Cancelled", requestDescription])

        networking?.cancel()

        // Prevent start() from have having any effect if it hasn't been called yet
        wasCancelled = true

        broadcastResponse(ResponseInfo.cancellation)
        }

    func repeated() -> Request
        {
        return NetworkRequest(resource: resource, requestBuilder: requestBuilder)
        }

    // MARK: Callbacks

    internal func addResponseCallback(_ callback: @escaping ResponseCallback) -> Self
        {
        responseCallbacks.addCallback(callback)
        return self
        }

    func onProgress(_ callback: @escaping (Double) -> Void) -> Self
        {
        progressTracker.callbacks.addCallback(callback)
        return self
        }

    // MARK: Response handling

    // Entry point for response handling. Triggered by RequestNetworking completion callback.
    private func responseReceived(underlyingResponse: HTTPURLResponse?, body: Data?, error: Error?)
        {
        DispatchQueue.mainThreadPrecondition()

        underlyingNetworkRequestCompleted = true

        debugLog(.network, ["Response: ", underlyingResponse?.statusCode ?? error, "←", requestDescription])
        debugLog(.networkDetails, ["Raw response headers:", underlyingResponse?.allHeaderFields])
        debugLog(.networkDetails, ["Raw response body:", body?.count ?? 0, "bytes"])

        let responseInfo = interpretResponse(underlyingResponse, body, error)

        if shouldIgnoreResponse(responseInfo.response)
            { return }

        transformResponse(responseInfo, then: broadcastResponse)
        }

    private func isError(httpStatusCode: Int?) -> Bool
        {
        guard let httpStatusCode = httpStatusCode else
            { return false }
        return httpStatusCode >= 400
        }

    private func interpretResponse(
            _ underlyingResponse: HTTPURLResponse?,
            _ body: Data?,
            _ error: Error?)
        -> ResponseInfo
        {
        if isError(httpStatusCode: underlyingResponse?.statusCode) || error != nil
            {
            return ResponseInfo(
                response: .failure(RequestError(response: underlyingResponse, content: body, cause: error)))
            }
        else if underlyingResponse?.statusCode == 304
            {
            if let entity = resource.latestData
                {
                return ResponseInfo(response: .success(entity), isNew: false)
                }
            else
                {
                return ResponseInfo(
                    response: .failure(RequestError(
                        userMessage: NSLocalizedString("No data available", comment: "userMessage"),
                        cause: RequestError.Cause.NoLocalDataFor304())))
                }
            }
        else
            {
            return ResponseInfo(response: .success(Entity<Any>(response: underlyingResponse, content: body ?? Data())))
            }
        }

    private func transformResponse(
            _ rawInfo: ResponseInfo,
            then afterTransformation: @escaping (ResponseInfo) -> Void)
        {
        let processor = config.pipeline.makeProcessor(rawInfo.response, resource: resource)

        DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async
            {
            let processedInfo =
                rawInfo.isNew
                    ? ResponseInfo(response: processor(), isNew: true)
                    : rawInfo

            DispatchQueue.main.async
                { afterTransformation(processedInfo) }
            }
        }

    private func broadcastResponse(_ newInfo: ResponseInfo)
        {
        DispatchQueue.mainThreadPrecondition()

        if shouldIgnoreResponse(newInfo.response)
            { return }

        progressTracker.complete()

        responseCallbacks.notifyOfCompletion(newInfo)
        }

    private func shouldIgnoreResponse(_ newResponse: Response) -> Bool
        {
        guard let existingResponse = responseCallbacks.completedValue?.response else
            { return false }

        // We already received a response; don't broadcast another one.

        if !existingResponse.isCancellation
            {
            debugLog(.network,
                [
                "WARNING: Received response for request that was already completed:", requestDescription,
                "This may indicate a bug in the NetworkingProvider you are using, or in Siesta.",
                "Please file a bug report: https://github.com/bustoutsolutions/siesta/issues/new",
                "\n    Previously received:", existingResponse,
                "\n    New response:", newResponse
                ])
            }
        else if !newResponse.isCancellation
            {
            // Sometimes the network layer sends a cancellation error. That’s not of interest if we already knew
            // we were cancelled. If we received any other response after cancellation, log that we ignored it.

            debugLog(.networkDetails,
                [
                "Received response, but request was already cancelled:", requestDescription,
                "\n    New response:", newResponse
                ])
            }

        return true
        }

    // MARK: Debug

    var debugDescription: String
        {
        return "Request:"
            + String(UInt(bitPattern: ObjectIdentifier(self)), radix: 16)
            + "("
            + requestDescription
            + ")"
        }
    }
