import Siesta
import SwiftyJSON

// Depending on your taste, a Service can be a global var, a static var singleton, or a piece of more carefully
// controlled shared state passed between pieces of the app.

let GitHubAPI = _GitHubAPI()

class _GitHubAPI {

    // MARK: Configuration

    private let service = Service(baseURL: "https://api.github.com")

    fileprivate init() {
        #if DEBUG
            // Bare-bones logging of which network calls Siesta makes:
            LogCategory.enabled = [.network]

            // For more info about how Siesta decides whether to make a network call,
            // and when it broadcasts state updates to the app:
            //LogCategory.enabled = LogCategory.common

            // For the gory details of what Siesta’s up to:
            //LogCategory.enabled = LogCategory.detailed
        #endif

        // Global configuration

        service.configure {
            // By default, Siesta parses JSON using Foundation JSONSerialization.
            // This transformer wraps that with SwiftyJSON.

            $0.pipeline[.parsing].add(SwiftyJSONTransformer, contentTypes: ["*/json"])

            // Custom transformers can change any response into any other — in this case, replacing the default error
            // message with the one provided by the Github API.

            $0.pipeline[.cleanup].add(GithubErrorMessageExtractor())
        }

        // Resource-specific configuration

        service.configure("/search/**") {
            $0.expirationTime = 10  // Refresh search results after 10 seconds (Siesta default is 30)
        }

        // Auth configuration

        // Note the "**" pattern, which makes this config apply only to subpaths of baseURL.
        // This prevents accidental credential leakage to untrusted servers.

        service.configure("**") {
            // This header configuration gets reapplied whenever the user logs in or out.
            // How? See the basicAuthHeader property’s didSet.

            $0.headers["Authorization"] = self.basicAuthHeader
        }

        // Mapping from specific paths to models

        service.configureTransformer("/users/*") {
            try User(json: $0.content)  // Input type inferred because User.init takes JSON
        }

        service.configureTransformer("/users/*/repos") {
            try ($0.content as JSON)   // “as JSON” gives Siesta the expected input type
                .arrayValue            // SwiftyJSON defaults to []
                .map(Repository.init)  // Model mapping gives Siesta an implicit output type
        }

        service.configureTransformer("/search/repositories") {
            try ($0.content as JSON)["items"]
                .arrayValue
                .map(Repository.init)
        }

        service.configureTransformer("/repos/*/*") {
            try Repository(json: $0.content)
        }

        service.configureTransformer("/repos/*/*/contributors") {
            try ($0.content as JSON)
                .arrayValue
                .map(User.init)
        }

        service.configure("/user/starred/*/*") {   // Github gives 202 for “starred” and 404 for “not starred.”
            $0.pipeline[.model].add(               // This custom transformer turns that curious convention into
                TrueIfResourceFoundTransformer())  // a resource whose content is a simple boolean.
        }

        // Note that you can use Siesta without these sorts of model mappings. By default, Siesta parses JSON, text,
        // and images based on content type — and a resource will contain whatever the server happened to return, in a
        // parsed but unstructured form (string, dictionary, etc.). If you prefer to work with raw dictionaries instead
        // of models (good for rapid prototyping), then no additional transformer config is necessary.
        //
        // If you do apply a path-based mapping like the ones above, then any request for that path that does not return
        // the expected type becomes an error. For example, "/users/foo" _must_ return a JSON response because that's
        // what the User(json:) expects.
    }

    // MARK: Authentication

    func logIn(username: String, password: String) {
        if let auth = "\(username):\(password)".data(using: String.Encoding.utf8) {
            basicAuthHeader = "Basic \(auth.base64EncodedString())"
        }
    }

    func logOut() {
        basicAuthHeader = nil
    }

    var isAuthenticated: Bool {
        return basicAuthHeader != nil
    }

    private var basicAuthHeader: String? {
        didSet {
            // These two calls are almost always necessary when you have changing auth for your API:

            service.invalidateConfiguration()  // So that future requests for existing resources pick up config change
            service.wipeResources()            // Scrub all unauthenticated data

            // Note that wipeResources() broadcasts a “no data” event to all observers of all resources.
            // Therefore, if your UI diligently observes all the resources it displays, this call prevents sensitive
            // data from lingering in the UI after logout.
        }
    }

    // MARK: Endpoints

    // You can turn your REST API into a nice Swift API using lightweight wrappers that return Siesta resources.
    //
    // Note that this class keeps its service private, making these methods the only entry points for the API.
    // You could also choose to subclass Service, which makes methods like service.resource(…) available to
    // your whole app. That approach is sometimes better for quick and dirty prototyping.

    var activeRepositories: Resource {
        return service
            .resource("/search/repositories")
            .withParam("q", "stars:>0")
            .withParam("sort", "updated")
            .withParam("order", "desc")
    }

    func user(_ username: String) -> Resource {
        return service
            .resource("/users")
            .child(username.lowercased())
    }

    func repository(ownedBy login: String, named name: String) -> Resource {
        return service
            .resource("/repos")
            .child(login)
            .child(name)
    }

    func repository(_ repositoryModel: Repository) -> Resource {
        return repository(
            ownedBy: repositoryModel.owner.login,
            named: repositoryModel.name)
    }

    func currentUserStarred(_ repositoryModel: Repository) -> Resource {
        return service
            .resource("/user/starred")
            .child(repositoryModel.owner.login)
            .child(repositoryModel.name)
    }

    func setStarred(_ isStarred: Bool, repository repositoryModel: Repository) -> Request {
        let starredResource = currentUserStarred(repositoryModel)
        return starredResource
            .request(isStarred ? .put : .delete)
            .onSuccess { _ in
                // Update succeeded. Directly update the locally cached “starred / not starred” state.

                starredResource.overrideLocalContent(with: isStarred)

                // Ask server for an updated star count. Note that we only need to trigger the load here, not handle
                // the response! Any UI that is displaying the star count will be observing this resource, and thus
                // will pick up the change. The code that knows _when_ to trigger the load is decoupled from the code
                // that knows _what_ to do with the updated data. This is the magic of Siesta.

                self.repository(repositoryModel).load()
            }
    }
}

/// If the response is JSON and has a "message" value, use it as the user-visible error message.
private struct GithubErrorMessageExtractor: ResponseTransformer {
    func process(_ response: Response) -> Response {
        switch response {
            case .success:
                return response

            case .failure(var error):
                // Note: the .json property here is defined in Siesta+SwiftyJSON.swift
                error.userMessage = error.json["message"].string ?? error.userMessage
                return .failure(error)
        }
    }
}

/// Special handling for detecting whether repo is starred; see "/user/starred/*/*" config above
private struct TrueIfResourceFoundTransformer: ResponseTransformer {
    func process(_ response: Response) -> Response {
        switch response {
            case .success(var entity):
                entity.content = true         // Any success → true
                return logTransformation(
                    .success(entity))

            case .failure(let error):
                if var entity = error.entity, error.httpStatusCode == 404 {
                    entity.content = false    // 404 → false
                    return logTransformation(
                        .success(entity))
                } else {
                    return response           // Any other error remains unchanged
                }
        }
    }
}
