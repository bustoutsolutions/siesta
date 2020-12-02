import RxSwift
import RxCocoa

extension _GitHubAPI {

    /*
    An unintrusive way to publish isAuthenticated - _GitHubAPI is shared with the other non-rx examples.
    In reality we'd do this differently.
    */
    var isAuthenticatedObservable: Observable<Bool> {
        rx.observe(String?.self, "basicAuthHeader").map { $0.map { $0 != nil} ?? false }.distinctUntilChanged()
    }

}