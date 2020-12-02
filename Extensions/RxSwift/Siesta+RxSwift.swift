//
//  Siesta+RxSwift.swift
//  Siesta
//
//  Created by Adrian on 2020/4/15.
//  Copyright © 2020 Bust Out Solutions. All rights reserved.
//

import Siesta
import RxSwift

// MARK: - Resources

/**
RxSwift extensions for Resource.

For usage examples see the following method comments, `RxSwiftSpec.swift` and the GitHubBrowser example project.

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

    Events are published on the main thread.

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

    /// The content, if it's present, otherwise nil. You'll get output from this for every event.
    public func optionalContent<T>() -> Observable<T?>
        {
        state().map { $0.content }
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


// MARK: - Requests

extension Reactive where Base: Resource
    {
    /**
    These methods produce cold observables - the request isn't started until subscription time. This will often be what
    you want, and you should at least consider preferring these methods over the Request.rx ones. This is particularly
    true when chaining requests using `Completable` - see `requestCompletable()`.

    If your request doesn't return data, you can ask for `Void`, in which case you'll get an element on completion, or
    `Never`, in which case you won't. Or you might prefer `requestCompletable()`.
    */
    public func request<T>(createRequest: @escaping (Resource) -> Request) -> Observable<T>
        {
        Observable.deferred { createRequest(self.base).rx.observable() }
        }

    /**
    (See also comments on `request()`.)

    If your request doesn't return data you can ask for `Void` - or you might prefer `requestCompletable()`.
    */
    public func requestSingle<T>(createRequest: @escaping (Resource) -> Request) -> Single<T>
        {
        Single.deferred { createRequest(self.base).rx.single() }
        }

    /**
    (See also comments on `request()`.)

    If you want to chain Completables to perform sequential requests, you're in the right place. `Request.rx.completable()`
    won't work for that (see its comments for an example).

    ```
    doSomethingResource.rx.requestCompletable { $0.request(.post) }
        .andThen(doSomethingNextResource.requestCompletable { $0.request(.post) }
        .subscribe { ... }
    ```
    */
    public func requestCompletable(createRequest: @escaping (Resource) -> Request) -> Completable
        {
        Completable.deferred { createRequest(self.base).rx.completable() }
        }
}

extension Request
    {
    /// Let's keep with the .rx convention. This can't be an extension of Reactive though because Request is a protocol.
    public var rx: RequestReactive { RequestReactive(request: self) }
    }

public struct RequestReactive
    {
    let request: Request

    /**
    Be cautious with these methods - Requests are started when they're created, so we're effectively creating hot observables here.
    Consider using the `Resource.rx.request*()` methods, which produce cold observables - requests won't start until subscription time.

    However, if you've been handed a Request and you want to make it reactive, these methods are here for you.

    If your request doesn't return data, you can ask for `Void`, in which case you'll get an element on completion, or
    `Never`, in which case you won't.
    */
    public func observable<T>() -> Observable<T>
        {
        Observable.create
            {
            observer in
            self.request.onSuccess
                {
                if T.self == Never.self
                    { /* no output */ }
                else if let result = () as? T
                    { observer.onNext(result) }
                else
                    {
                    guard let result: T = $0.typedContent() else
                        {
                        observer.onError(RequestError(userMessage: "Wrong content type",
                                cause: RequestError.Cause.WrongContentType()))
                        return
                        }
                    observer.onNext(result)
                    }
                observer.onCompleted()
                }

            self.request.onFailure { observer.onError($0) }

            return Disposables.create()
            }
            .observeOn(MainScheduler.instance)
        }

    /**
    Caution - see comments on `observable()`.

    You can get yourself into trouble trying to chain requests with this method (see `Resource.rx.requestCompletable()`
    for a working version of this code):

    ```
    doSomethingResource.request(.post).rxCompletable
        .andThen(api.doSomethingNextResource.request(.post).rxCompletable) // Nooooo. Started immediately, not after doSomething.
        .subscribe { ... }
    ```
    */
    public func completable() -> Completable
        {
        (observable() as Observable<Never>).asCompletable()
        }

    /**
    Caution - see comments on `observable()`.

    If your request doesn't return data, you can ask for `Void`.
    */
    public func single<T>() -> Single<T>
        {
        observable().asSingle()
        }
    }
