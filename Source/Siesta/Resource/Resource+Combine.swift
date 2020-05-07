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

For basic usage examples see `CombineSpec.swift`.
*/
@available(iOS 13, tvOS 13, OSX 10.15, watchOS 6.0, *)
extension Resource
	{
    /**
    The changing state of the resource, corresponding to the resource's events.

    Note that content is typed; you'll get an error (in latestError) if your resource doesn't produce
    the type you specify.

    Subscribing to this publisher triggers a call to `loadIfNeeded()`, which is probably what you want.

    As with non-reactive Siesta, you'll immediately get an event (`observerAdded`) describing the current
    state of the resource.

    The publisher will never error out, or in fact complete at all. Please dispose of your subscriptions
    appropriately, otherwise you'll have a permanent reference to the resource.

    Events are published on the main thread.

    Note that as befits network operations, Siesta's Combine methods produce cold observables. What
    that means here is that network ops don't happen until subscription time. This is particularly
    important when dealing with `Request` (see request methods below). (If you don't know about hot
    and cold observables, stop putting it off and read
    https://github.com/ReactiveX/RxSwift/blob/master/Documentation/HotAndColdObservables.md)
    */
    public func statePublisher<T>() -> AnyPublisher<ResourceState<T>,Never>
        {
        EventPublisher(resource: self)
            .receive(on: DispatchQueue.main)
            .map { resource, event in resource.snapshot(latestEvent: event) }
            .eraseToAnyPublisher()
        }

    /**
    Just the content, when present. Note this doesn't error out - by using this, you're saying you
    don't care about errors at all.

    Otherwise, see comments for `statePublisher()`
    */
    public func contentPublisher<T>() -> AnyPublisher<T,Never>
        {
        statePublisher().content()
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

    // MARK: - Requests

    /**
	Publisher for a request whose response body we don't care about.
    This isn't an extension of `Request`, as requests are started when they're created, effectively
    creating hot publishers (see comments on `state()`). We want to defer request creation until
    subscription time.
    */
    public func requestPublisher(createRequest: @escaping (Resource) -> Request) -> AnyPublisher<Void, RequestError>
		{
        Deferred
			{
            Future
				{
                promise in
                createRequest(self)
                        .onSuccess { _ in promise(.success(())) }
                        .onFailure { promise(.failure($0)) }
        		}
			}
            .eraseToAnyPublisher()
    	}

	/// Publisher for a request that returns data. Strongly typed, like the Resource publishers.
    public func dataRequestPublisher<T>(createRequest: @escaping (Resource) -> Request) -> AnyPublisher<T, RequestError>
		{
        Deferred
			{
            Future
				{
                promise in
                createRequest(self)
                        .onSuccess
                        {
                        guard let result: T = $0.typedContent() else
							{
                            promise(.failure(RequestError(userMessage: "Wrong content type",
                                    cause: RequestError.Cause.WrongContentType())))
                            return
                        	}
                        promise(.success(result))
                        }

                        .onFailure
							{ promise(.failure($0)) }
    			}
	        }
            .eraseToAnyPublisher()
    	}
    }

@available(iOS 13, tvOS 13, OSX 10.15, watchOS 6.0, *)
extension AnyPublisher
    {
    /// See comments on `Resource.contentPublisher()`
    public func content<T>() -> AnyPublisher<T,Failure> where Output == ResourceState<T>
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
    public struct WrongContentType: Error {
        public init() {}
    }
    }
