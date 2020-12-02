import Combine

extension _GitHubAPI {

    /*
    An unintrusive way to publish isAuthenticated - _GitHubAPI is shared with the other non-Combine examples.
    In reality if we were using a stored property we'd annotate with @Published.
    */
    var isAuthenticatedPublisher: AnyPublisher<Bool, Never> {
        publisher(for: \.basicAuthHeader)
                .map { $0 != nil }
                .eraseToAnyPublisher()
    }

}