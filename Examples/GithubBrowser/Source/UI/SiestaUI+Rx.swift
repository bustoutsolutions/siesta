import Siesta
import RxSwift

/*
A quick way to get RxSwift compatibility for ResourceStatusOverlay. A more elaborate alternative would
be to write a version of ResourceStatusOverlay that understands ResourceState observables.
*/
extension ObservableType where Element == Resource {

    func watchedBy(statusOverlay: ResourceStatusOverlay) -> Observable<Resource> {
        withPrevious()
                .do(onNext: {
                    $0.previous?.removeObservers(ownedBy: statusOverlay)
                    $0.current.addObserver(statusOverlay)
                })
                .map { $0.current }
    }
}

extension ObservableType where Element == Resource? {

    func watchedBy(statusOverlay: ResourceStatusOverlay) -> Observable<Resource?> {
        withPrevious()
                .do(onNext: {
                    $0.previous??.removeObservers(ownedBy: statusOverlay)
                    $0.current?.addObserver(statusOverlay)
                })
                .map { $0.current }
    }
}

fileprivate extension ObservableType {

    func withPrevious() -> Observable<(previous: Element?, current: Element)> {
        scan(nil) { (previous: $0?.current, current: $1) }.compactMap { $0 }
    }
}

