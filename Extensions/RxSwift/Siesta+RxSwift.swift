//
//  Siesta+RxSwift.swift
//  Siesta
//
//  Created by Adrian on 2020/4/15.
//  Copyright © 2020 Bust Out Solutions. All rights reserved.
//

import Siesta
import RxSwift

/**
RxSwift extensions for Resource. You need ../ReactiveCommon.swift as well as this file.

For basic usage examples see the following method comments and `RxSwiftSpec.swift`.

Following RxSwift's convention, we add methods to `myResource.rx`, not to `myResource` directly.
*/
extension Reactive where Base: Resource
    {
    /**
    The changing state of the resource, corresponding to the resource's events.

    Note that content is typed; you'll get an error (in latestError) if your resource doesn't produce
    the type you imply.

    Subscribing to this sequence triggers a call to `loadIfNeeded()`, which is probably what you want.
    For example, it lets you do things like this, refreshing the resource whenever the view appears:

    ```
    func viewDidLoad() {
        ...
        rx.viewWillAppear  // theoretical reactive extension to UIViewController implemented using rx.methodInvoked
            .flatMapLatest {
                api.interestingThing.rx.state()
            }
            .subscribe { [weak self] (state: ResourceState&lt;InterestingThing&gt;) in
                ...
            }
            .disposed(by: disposeBag)
    }
    ```

    As with non-rx, you'll immediately get an event (`observerAdded`) describing the current state of the resource.

    The sequence will never error out, or in fact complete at all. Please dispose of your subscriptions
    appropriately, otherwise you'll have a permanent reference to the resource.

    Events are published on the main thread. Make sure you subscribe on the main thread.

    Note that as befits network operations, the methods in this extension produce cold observables. What
    that means here is that network ops don't happen until subscription time. This is particularly
    important when dealing with `Request` (see request methods below). (If you don't know about hot and cold
    observables, stop putting it off and read
    https://github.com/ReactiveX/RxSwift/blob/master/Documentation/HotAndColdObservables.md)

    Why doesn't this return `Driver`, especially since the request methods use traits rather than plain
    observables? Mainly because Driver is in RxCocoa, and I didn't want to import that here. (There's probably
    an argument to be made that Driver ought to be in RxSwift - although it's useful when writing UI code,
    it's not *only* useful for that.) With reference to driver's characteristics:
    - events are published on the main thread, like Driver
    - doesn't error out, like Driver
    - you get the resource state as soon as you subscribe (via the observerAdded event), so you effectively
      have replay(1) here too
    */
    public func state<T>() -> Observable<ResourceState<T>>
        {
        events().map { resource, event in resource.snapshot(latestEvent: event) }
        }

    /**
    Just the content, when present. Note this doesn't error out either - by using this, you're saying you
    don't care about errors at all.

    Otherwise, see comments for `state()`
    */
    public func content<T>() -> Observable<T>
        {
        state().content()
        }

    private func events() -> Observable<(Resource, ResourceEvent)>
        {
        Observable<(Resource, ResourceEvent)>.create
            {
            observer in
            let owner = SyntheticOwner()

            self.base.addObserver(owner: owner) { observer.onNext(($0, $1)) }

            self.base.loadIfNeeded()

            return Disposables.create { self.base.removeObservers(ownedBy: owner) }
            }
            .observeOn(MainScheduler.instance)
    }

    private class SyntheticOwner {}


    /**
    This isn't an extension of `Request`, as requests are started when they're created, effectively
    creating hot observables (see comments on `state()`). Here's why an `rx.completable` extension
    on `Request` would be bad:

    ```
    api.doSomething.request(.post).rx.completable
        .andThen(api.doSomethingNext.request(.post).rx.completable) // Nooooo. Started immediately, not after doSomething.
        .subscribe { ... }
    ```
    --

    A working version of sequential requests looks like this:

    ```
    api.doSomething.rx.request { $0.request(.post) }
        .andThen(api.doSomethingNext.request { $0.request(.post) }
        .subscribe { ... }
    ```
    */
    public func request(createRequest: @escaping (Resource) -> Request) -> Completable
        {
        Completable.create
            {
            observer in
            let request = createRequest(self.base)
            request.onSuccess { _ in observer(.completed) }

            request.onFailure { observer(.error($0)) }

            return Disposables.create()
            }
            .observeOn(MainScheduler.instance)
        }

    /**
    Specifically for requests that return data. If you have one that doesn't, use `request()`. (Don't
    instead try using `Void` for your `T` here - that will fail.)

    Otherwise, see comments on `request()`.
    */
    public func requestWithData<T>(createRequest: @escaping (Resource) -> Request) -> Single<T>
        {
        Single<T>.create
            {
            observer -> Disposable in
            let request = createRequest(self.base)
            request.onSuccess
                {
                guard let result: T = $0.typedContent() else
                    {
                    observer(.error(RequestError(userMessage: "Wrong content type",
                            cause: RequestError.Cause.WrongContentType())))
                    return
                    }
                observer(.success(result))
                }

            request.onFailure { observer(.error($0)) }

            return Disposables.create()
            }
            .observeOn(MainScheduler.instance)
    }
}

extension ObservableType
    {
    /// See comments on `Resource.rx.content()`
    public func content<T>() -> Observable<T> where Element == ResourceState<T>
        {
        compactMap { $0.content }
        }
    }


extension Resource
    {
    /// A direct copy from Siesta's Combine implementation.
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
