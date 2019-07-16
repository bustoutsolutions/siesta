import Siesta

// Depending on your taste, a Service can be a global var, a static var singleton, or a piece of more carefully
// controlled shared state passed between pieces of the app.

let GitHubAPI = _GitHubAPI()

class _GitHubAPI {

    // MARK: - Configuration

    private let service = Service(
        baseURL: "https://api.github.com",
        standardTransformers: [.text, .image])  // No .json because we use Swift 4 JSONDecoder instead of older JSONSerialization

    fileprivate init() {
        #if DEBUG
            // Bare-bones logging of which network calls Siesta makes:
            SiestaLog.Category.enabled = [.network]

            // For more info about how Siesta decides whether to make a network call,
            // and which state updates it broadcasts to the app:

            //SiestaLog.Category.enabled = .common

            // For the gory details of what Siesta’s up to:

            //SiestaLog.Category.enabled = .detailed

            // To dump all requests and responses:
            // (Warning: may cause Xcode console overheating)

            //SiestaLog.Category.enabled = .all
        #endif

        // –––––– Global configuration ––––––

        let jsonDecoder = JSONDecoder()

        service.configure {
            // Custom transformers can change any response into any other — including errors.
            // Here we replace the default error message with the one provided by the GitHub API (if present).

            $0.pipeline[.cleanup].add(
              GitHubErrorMessageExtractor(jsonDecoder: jsonDecoder))
        }

        // –––––– Resource-specific configuration ––––––

        service.configure("/search/**") {
            // Refresh search results after 10 seconds (Siesta default is 30)
            $0.expirationTime = 10
        }

        // –––––– Auth configuration ––––––

        // Note the "**" pattern, which makes this config apply only to subpaths of baseURL.
        // This prevents accidental credential leakage to untrusted servers.

        service.configure("**") {
            // This header configuration gets reapplied whenever the user logs in or out.
            // How? See the basicAuthHeader property’s didSet.

            $0.headers["Authorization"] = self.basicAuthHeader
        }

        // –––––– Mapping from specific paths to models ––––––

        // These all use Swift 4’s JSONDecoder, but you can configure arbitrary transforms on arbitrary data types.

        service.configureTransformer("/users/*") {
            // Input type inferred because the from: param takes Data.
            // Output type inferred because jsonDecoder.decode() will return User
            try jsonDecoder.decode(User.self, from: $0.content)
        }

        service.configureTransformer("/users/*/repos") {
            try jsonDecoder.decode([Repository].self, from: $0.content)
        }

        service.configureTransformer("/search/repositories") {
            try jsonDecoder.decode(SearchResults<Repository>.self, from: $0.content)
                .items  // Transformers can do arbitrary post-processing
        }

        service.configureTransformer("/repos/*/*") {
            try jsonDecoder.decode(Repository.self, from: $0.content)
        }

        service.configureTransformer("/repos/*/*/contributors") {
            try jsonDecoder.decode([User].self, from: $0.content)
        }

        service.configureTransformer("/repos/*/*/languages") {
            // For this request, GitHub gives a response of the form {"Swift": 421956, "Objective-C": 11000, ...}.
            // Instead of using a custom model class for this one, we just model it as a raw dictionary.
            try jsonDecoder.decode([String:Int].self, from: $0.content)
        }

        service.configure("/user/starred/*/*") {   // GitHub gives 202 for “starred” and 404 for “not starred.”
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
        // what jsonDecoder.decode(…) expects.
    }

    // MARK: - Authentication

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

    // MARK: - Endpoint Accessors

    // You can turn your REST API into a nice Swift API using lightweight wrappers that return Siesta resources.
    //
    // Note that this class keeps its Service private, making these methods the only entry points for the API.
    // You could also choose to subclass Service, which makes methods like service.resource(…) available to
    // your whole app. That approach is sometimes better for quick and dirty prototyping.
    //
    // If this section gets too long for your taste, you can move it to a separate file by putting a helper method
    // in an extension.

    var activeRepositories: Resource {
        return service
            .resource("/search/repositories")
            .withParams([
                "q": "stars:>0",
                "sort": "updated",
                "order": "desc"
            ])
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

                for delay in [0.1, 1.0, 2.0] {  // Github propagates the updated star count slowly
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        // This ham-handed repeated loading is not as expensive as it first appears, thanks to the fact
                        // that Siesta magically takes care of ETag / If-modified-since / HTTP 304 for us.
                        self.repository(repositoryModel).load()
                    }
                }
            }
    }
}

// MARK: - Custom transformers

/// If the response is JSON and has a "message" value, use it as the user-visible error message.
private struct GitHubErrorMessageExtractor: ResponseTransformer {
    let jsonDecoder: JSONDecoder

    func process(_ response: Response) -> Response {
        guard case .failure(var error) = response,     // Unless the response is a failure...
          let errorData: Data = error.typedContent(),  // ...with data...
          let githubError = try? jsonDecoder.decode(   // ...that encodes a standard GitHub error envelope...
            GitHubErrorEnvelope.self, from: errorData)
        else {
          return response                              // ...just leave it untouched.
        }

        error.userMessage = githubError.message        // GitHub provided an error message. Show it to the user!
        return .failure(error)
    }

    private struct GitHubErrorEnvelope: Decodable {
        let message: String
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
                if error.httpStatusCode == 404, var entity = error.entity {
                    entity.content = false    // 404 → false
                    return logTransformation(
                        .success(entity))
                } else {
                    return response           // Any other error remains unchanged
                }
        }
    }
}
