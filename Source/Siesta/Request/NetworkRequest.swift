//
//  NetworkRequest.swift
//  Siesta
//
//  Created by Paul on 2015/12/15.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import Foundation

internal final class NetworkRequest: AbstractRequest
    {
    // Basic metadata
    private let resource: Resource
    internal var config: Configuration
        { return resource.configuration(for: underlyingRequest) }

    // Networking
    private let requestBuilder: () -> URLRequest      // so repeated() can re-read config
    private let underlyingRequest: URLRequest
    internal var underlyingRequestInProgress = false  // so tests can wait for it to finish
    internal var networking: RequestNetworking?       // present only after start()

    // Progress
    private var progressTracker: ProgressTracker

    // MARK: Managing request

    init(resource: Resource, requestBuilder: @escaping () -> URLRequest)
        {
        self.resource = resource
        self.requestBuilder = requestBuilder
        underlyingRequest = requestBuilder()
        progressTracker = ProgressTracker(isGet: underlyingRequest.httpMethod == "GET")  // URLRequest automatically uppercases method

        super.init(requestDescription:
            LogCategory.enabled.contains(.network) || LogCategory.enabled.contains(.networkDetails)
                ? debugStr([underlyingRequest.httpMethod, underlyingRequest.url])
                : "")
        }

    override func startUnderlyingOperation()
        {
        underlyingRequestInProgress = true

        let networking = resource.service.networkingProvider.startRequest(underlyingRequest)
            {
            res, data, err in
            DispatchQueue.main.async
                {
                self.underlyingRequestInProgress = false
                self.responseReceived(underlyingResponse: res, body: data, error: err)
                }
            }
        self.networking = networking

        progressTracker.start(
            networking,
            reportingInterval: config.progressReportingInterval)
        }

    override func cancelUnderlyingOperation()
        {
        networking?.cancel()
        }

    override func willNotifyCompletionCallbacks()
        {
        progressTracker.complete()
        }

    override func repeated() -> Request
        {
        return NetworkRequest(resource: resource, requestBuilder: requestBuilder)
        }

    // MARK: Progress

    override var progress: Double
        { return progressTracker.progress }

    override func onProgress(_ callback: @escaping (Double) -> Void) -> Request
        {
        progressTracker.callbacks.addCallback(callback)
        return self
        }

    // MARK: Response handling

    // Entry point for response handling. Triggered by RequestNetworking completion callback.
    private func responseReceived(underlyingResponse: HTTPURLResponse?, body: Data?, error: Error?)
        {
        DispatchQueue.mainThreadPrecondition()

        debugLog(.network, ["Response: ", underlyingResponse?.statusCode ?? error, "←", description])
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
    }
