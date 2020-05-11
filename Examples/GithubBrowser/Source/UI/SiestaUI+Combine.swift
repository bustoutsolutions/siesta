import Siesta
import Combine

/*
A quick way to get Combine compatibility for ResourceStatusOverlay. A more elaborate alternative would
be to write a version of ResourceStatusOverlay that understands ResourceState publishers.
*/
extension Publisher where Output == Resource {

    func watchedBy(statusOverlay: ResourceStatusOverlay) -> AnyPublisher<Output, Failure> {
        withPrevious()
                .handleEvents(receiveOutput: {
                    $0.previous?.removeObservers(ownedBy: statusOverlay)
                    $0.current.addObserver(statusOverlay)
                })
                .map { $0.current }
                .eraseToAnyPublisher()
    }
}

extension Publisher where Output == Resource? {

    func watchedBy(statusOverlay: ResourceStatusOverlay) -> AnyPublisher<Output, Failure> {
        withPrevious()
                .handleEvents(receiveOutput: {
                    $0.previous??.removeObservers(ownedBy: statusOverlay)
                    $0.current?.addObserver(statusOverlay)
                })
                .map { $0.current }
                .eraseToAnyPublisher()
    }
}

fileprivate extension Publisher {

    func withPrevious() -> AnyPublisher<(previous: Output?, current: Output), Failure> {
        scan(nil) { (previous: $0?.current, current: $1) }.compactMap { $0 }.eraseToAnyPublisher()
    }
}

