//
//  Siesta+RxCocoa.swift
//  Siesta
//
//  Created by Stas Chmilenko on 18.01.17.
//  Copyright © 2017 Bust Out Solutions. All rights reserved.
//

import Siesta
import RxSwift
import RxCocoa

// MARK: - Resource extension
// MARK: Basic rx functionality
/**
 Extending reactive struct so Rx extension functionality available through .rx method on resources
 
 Example of usage:
     class ViewController: UIViewController {
     
         let resource = Api.users.child("253")
         
         @IBOutlet weak var eventLabel: UILabel!
         @IBOutlet weak var loadingLabel: UILabel!
         @IBOutlet weak var requestLabel: UILabel!
         @IBOutlet weak var errorLabel: UILabel!
         @IBOutlet weak var dataLabel: UILabel!
         
         let disposeBag = DisposeBag()
         
         override func viewDidLoad() {
             super.viewDidLoad()
             resource.rx.changes
                 .map { "\($0.event)" }
                 .drive(eventLabel.rx.text)
                 .addDisposableTo(disposeBag)
             resource.rx.isLoading
                 .map { "\($0)" }
                 .drive(loadingLabel.rx.text)
                 .addDisposableTo(disposeBag)
             resource.rx.isRequesting
                 .map { "\($0)" }
                 .drive(requestLabel.rx.text)
                 .addDisposableTo(disposeBag)
             resource.rx.latestError
                 .map { "\($0)" }
                 .drive(errorLabel.rx.text)
                 .addDisposableTo(disposeBag)
             resource.rx.jsonDict
                 .map { "\($0)" }
                 .drive(dataLabel.rx.text)
                 .addDisposableTo(disposeBag)
         }
         
         @IBAction func click(_ sender: Any) {
             resource.loadIfNeeded()
         }
     
     }
 
 I'm using Driver<T> throughout extension instead of simple Observable<T> because
 resource changes better suits to semantic of Driver from RxCocoa.
 */
extension Reactive where Base: Resource
    {
    /// Creates observable returning latest state of resource end event changed it.
    public var changes: Driver<(resource: Resource, event: ResourceEvent)>
        {
        return createObservable().map { (resource: $0, event: $1) }
            .asDriver(onErrorJustReturn: (resource: self.base, event: .error))
        }
    
    /// Creates observable returning latestData.
    public var latestData: Driver<Entity<Any>?>
        {
        return createObservable().map { $0.0.latestData }
            .asDriver(onErrorJustReturn: nil)
        }
    
    /// Creates observable returning latestError.
    public var latestError: Driver<RequestError?>
        {
        return createObservable().map { $0.0.latestError }
            .asDriver(onErrorJustReturn: nil)
        }
    
    /// Creates observable returning isLoading.
    public var isLoading: Driver<Bool>
        {
        return createObservable().map { $0.0.isLoading }
            .asDriver(onErrorJustReturn: false)
        }
    
    /// Creates observable returning isRequesting.
    public var isRequesting: Driver<Bool>
        {
        return createObservable().map { $0.0.isRequesting }
            .asDriver(onErrorJustReturn: false)
        }
    
    /// Creates observable listening for resource changes and removing listener on disposing of it.
    private func createObservable() -> Observable<(Resource, ResourceEvent)>
        {
        return Observable.create
            {
            observer in
            let owner = ObserverOwner()
            self.base.addObserver(owner: owner) { observer.onNext($0) }
            return Disposables.create
                {
                self.base.removeObservers(ownedBy: owner)
                }
            }
        }
    }

/// Class used as plaseholder for resource observer owner
private class ObserverOwner {}
// MARK: ObservableTypedContentAccessors
/**
 Brings functionality of TypedContentAccessors to Rx extension of Resource.
 I couldn't figure out how to write it as protocol because expressions like
 extension Reactive: ObservableTypedContentAccessors where Base: Resource
 not supported
 */
public extension Reactive where Base: Resource
    {
    public func typedContent<T>(ifNone defaultContent: @escaping @autoclosure () -> T) -> Driver<T>
        {
        return latestData.map
            {
            entityForTypedContent in
            return (entityForTypedContent?.content as? T) ?? defaultContent()
            }
        }
    
    public func typedContent<T>(ifNone defaultContent: @escaping @autoclosure () -> T?) -> Driver<T?>
        {
        return latestData.map
            {
            entityForTypedContent in
            return (entityForTypedContent?.content as? T) ?? defaultContent()
            }
        }
    
    public func typedContent<T>() -> Driver<T?>
        {
        return typedContent(ifNone: nil)
        }
    
    
    public var jsonDict: Driver<[String:Any]> { return typedContent(ifNone: [:]) }
    
    public var jsonArray: Driver<[Any]>       { return typedContent(ifNone: []) }
    
    public var text: Driver<String>           { return typedContent(ifNone: "") }
    }

// MARK: - Request
public extension Reactive where Base: Request
    {
    /// Creates subscrioption on request events end reemit it to rx Observable
    // Question: should it implisitly call start() on subscrioption?
    public func asObservable() -> Observable<Entity<Any>>
        {
        return Observable.create
            {
            observer in
            self.base.onSuccess
                {
                entity in
                observer.onNext(entity)
                observer.onCompleted()
                }
            self.base.onFailure
                {
                error in
                observer.onError(error)
                }
//            self.base.start()
            return Disposables.create
                {
                self.base.cancel()
                }
            }
        }
    
    public func progress() -> Observable<Double>
        {
        return Observable.create
            {
            observer in
            self.base.onProgress
                {
                progress in
                observer.onNext(progress)
                if progress == 1 { observer.onCompleted() }
                }
            return Disposables.create()
            }
        }
    }
