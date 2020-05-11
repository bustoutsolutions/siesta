//
//  Resource+Combine.swift
//  Siesta
//
//  Created by Adrian on 2020/04/27.
//  Copyright © 2020 Bust Out Solutions. All rights reserved.
//

#if canImport(Combine)

import Combine

/**
Combine extensions for Resource.

For usage examples see `CombineSpec.swift` and the GitHubBrowser example project.
*/
@available(iOS 13, tvOS 13, OSX 10.15, watchOS 6.0, *)
extension Resource
	{
    /**
    The changing state of the resource, corresponding to the resource's events.

    Note that content is typed; you'll get an error (in `latestError`) if your resource doesn't produce
    the type you specify.

    Subscribing to this publisher triggers a call to `loadIfNeeded()`, which is probably what you want.

    As with non-reactive Siesta, you'll immediately get an event (`observerAdded`) describing the current
    state of the resource.

    The publisher will never complete. Please dispose of your subscriptions appropriately otherwise you'll have
    a permanent reference to the resource.

    Events are published on the main thread.
    */
    public func statePublisher<T>() -> AnyPublisher<ResourceState<T>,Never>
        {
        EventPublisher(resource: self)
            .receive(on: DispatchQueue.main)
            .map { resource, event in resource.snapshot(latestEvent: event) }
            .eraseToAnyPublisher()
        }

    /**
    Just the content, when present. See also `statePublisher()`.
    */
    public func contentPublisher<T>() -> AnyPublisher<T,Never>
        {
        statePublisher().content()
        }

    /// The content, if it's present, otherwise nil. You'll get output from this for every event.
    /// See also `statePublisher()`.
    public func optionalContentPublisher<T>() -> AnyPublisher<T?,Never>
        {
        statePublisher().optionalContent()
        }

    fileprivate struct EventPublisher: Publisher
		{
        typealias Output = (Resource, ResourceEvent)
        typealias Failure = Never

        let resource: Resource

        init(resource: Resource)
			{ self.resource = resource }

        func receive<S>(subscriber: S) where S: Subscriber, Output == S.Input
			{
            let subscription = EventSubscription(subscriber: subscriber, resource: resource)
            subscriber.receive(subscription: subscription)
            resource.loadIfNeeded()
        	}
    	}

    fileprivate class EventSubscription<SubscriberType: Subscriber>: Subscription, ResourceObserver where SubscriberType.Input == (Resource,ResourceEvent)
		{
        private var subscriber: SubscriberType?
        private weak var resource: Resource?
        private var demand: Subscribers.Demand = .none
        private var observing = false

        init(subscriber: SubscriberType, resource: Resource)
			{
            self.subscriber = subscriber
            self.resource = resource
        	}

        func request(_ demand: Subscribers.Demand)
			{
            self.demand += demand
            if !observing
				{
                observing = true
                resource?.addObserver(self)
            	}
        	}

        func resourceChanged(_ resource: Resource, event: ResourceEvent)
			{
            guard demand > 0, let subscriber = subscriber else
				{ return }
            demand -= 1
            demand += subscriber.receive((resource, event))
        	}

        func cancel()
			{ subscriber = nil }
        }
    }

@available(iOS 13, tvOS 13, OSX 10.15, watchOS 6.0, *)
extension AnyPublisher
    {
    /// See comments on `Resource.contentPublisher()`
    public func content<T>() -> AnyPublisher<T, Failure> where Output == ResourceState<T>
        { compactMap { $0.content }.eraseToAnyPublisher() }

    /// See comments on `Resource.optionalContentPublisher()`
    public func optionalContent<T>() -> AnyPublisher<T?, Failure> where Output == ResourceState<T>
        { compactMap { $0.content }.eraseToAnyPublisher() }
    }

#endif


// MARK: - ResourceState

/**
Immutable state of a resource at a point in time - used for Combine publishers, but also suitable for other reactive
frameworks such as RxSwift, for which there is an optional Siesta extension.

Note the strong typing. If there is content but it's not of the type specified, `latestError` is populated
with a cause of `RequestError.Cause.WrongContentType`.
*/
public struct ResourceState<T>
    {
    /// Resource.latestData?.typedContent(). If the resource produces content of a different type you get an error.
    public let content: T?
    /// Resource.latestError
    public let latestError: RequestError?
    /// Resource.isLoading
    public let isLoading: Bool
    /// Resource.isRequesting
    public let isRequesting: Bool

    /**
    Usually the other fields of this struct are sufficient, but sometimes it's useful to have access to
    actual resource events, for example if you're recording network errors somewhere.
    */
    public let latestEvent: ResourceEvent

	/// Create
    public init(content: T?, latestError: RequestError?, isLoading: Bool, isRequesting: Bool, latestEvent: ResourceEvent)
		{
        self.content = content
        self.latestError = latestError
        self.isLoading = isLoading
        self.isRequesting = isRequesting
        self.latestEvent = latestEvent
    	}

    /// Transform state into a different content type
    public func map<Other>(transform: (T) -> Other) -> ResourceState<Other>
        {
        ResourceState<Other>(
            content: content.map(transform),
            latestError: latestError,
            isLoading: isLoading,
            isRequesting: isRequesting,
            latestEvent: latestEvent)
        }
    }

extension Resource
	{
    /// The current state of the resource. Note the RxSwift extension also has a copy of this method as it's
    /// not really suitable for adding to the public API.
    fileprivate func snapshot<T>(latestEvent: ResourceEvent)
        -> ResourceState<T>
        {
        let content: T? = latestData?.typedContent()
        let contentTypeError: RequestError? =
            (latestData != nil && content == nil)
                ? RequestError(
                    userMessage: "The server return an unexpected response type",
                    cause: RequestError.Cause.WrongContentType())
                : nil

        return ResourceState<T>(
                content: content,
                latestError: latestError ?? contentTypeError,
                isLoading: isLoading,
                isRequesting: isRequesting,
                latestEvent: latestEvent
        )
        }
	}

extension RequestError.Cause
    {
    public struct WrongContentType: Error
        {
        public init() {}
        }
    }


// MARK: - Requests

@available(iOS 13, tvOS 13, OSX 10.15, watchOS 6.0, *)
extension Resource
    {
    /**
    These methods produce cold observables - the request isn't started until subscription time. This will often be what
    you want, and you should at least consider preferring these methods over the Request publishers.

    Publisher for a request that doesn't return data.
    */
    public func requestPublisher(createRequest: @escaping (Resource) -> Request) -> AnyPublisher<Void, RequestError>
		{
        Deferred { createRequest(self).publisher() }.eraseToAnyPublisher()
    	}

	/**
	Publisher for a request that returns data. Strongly typed, like the Resource publishers.

	See also `requestPublisher()`
	*/
    public func dataRequestPublisher<T>(createRequest: @escaping (Resource) -> Request) -> AnyPublisher<T, RequestError>
		{
        Deferred { createRequest(self).dataPublisher() }.eraseToAnyPublisher()
    	}
    }

@available(iOS 13, tvOS 13, OSX 10.15, watchOS 6.0, *)
extension Request
    {
    /**
    Be cautious with these methods - Requests are started when they're created, so we're effectively creating hot observables here.
    Consider using the `Resource.*requestPublisher()` methods, which produce cold observables - requests won't start until
    subscription time.

    However, if you've been handed a Request and you want to make it reactive, these methods are here for you.

    Publisher for a request that doesn't return data.
    */
    public func publisher() -> AnyPublisher<Void, RequestError>
        {
        dataPublisher()
        }

    /**
   	Publisher for a request that returns data. Strongly typed, like the Resource publishers.

   	See also `publisher()`
   	*/
    public func dataPublisher<T>() -> AnyPublisher<T, RequestError>
        {
        Future
            {
            promise in
            self.onSuccess
                {
                if let result = () as? T
                    { promise(.success(result)) }
                else
                    {
                    guard let result: T = $0.typedContent() else
                        {
                        promise(.failure(RequestError(userMessage: "Wrong content type",
                                cause: RequestError.Cause.WrongContentType())))
                        return
                        }
                    promise(.success(result))
                    }
                }

            self.onFailure { promise(.failure($0)) }
            }
            .eraseToAnyPublisher()
        }
    }
