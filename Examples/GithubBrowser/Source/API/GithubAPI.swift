import Siesta
import SwiftyJSON

// Depending on your taste, a Service can be a global var, a static var singleton, or a piece of more carefully
// controlled shared state passed between pieces of the app.

let GithubAPI = _GithubAPI()

class _GithubAPI {

    // MARK: Configuration

    private let service = Service(baseURL: "https://api.github.com")

    private init() {
        #if DEBUG
            Siesta.enabledLogCategories = LogCategory.detailed
        #endif

        // Global configuration

        service.configure {
            // basicAuthHeader property’s didSet causes this config to be reapplied whenever auth changes

            $0.config.headers["Authorization"] = self.basicAuthHeader

            // By default, Siesta parses JSON using NSJSONSerialization. This example wraps that with SwiftyJSON.

            $0.config.pipeline[.parsing].add(SwiftyJSONTransformer, contentTypes: ["*/json"])

            // Custom transformers can change any response into any other — in this case, replacing the default error
            // message with the one provided by the Github API.

            $0.config.pipeline[.cleanup].add(GithubErrorMessageExtractor())
        }

        // Mapping from specific paths to models

        service.configureTransformer("/users/*") {
            try User(json: $0.content)  // Input type inferred because User.init takes JSON
        }

        service.configureTransformer("/users/*/repos") {
            try ($0.content as JSON).arrayValue.map(Repository.init)  // “as JSON” gives Siesta an explicit input type
        }

        service.configureTransformer("/repos/*/*") {
            try Repository(json: $0.content)
        }

        service.configure("/user/starred/*/*") {   // Github gives 202 for “starred” and 404 for “not starred.”
            $0.config.pipeline[.model].add(        // This custom transformer turns that curious convention into
                TrueIfResourceFoundTransformer())  // a resource whose content is a simple boolean.
        }

        // Note that you can use Siesta without these sorts of model mappings. By default, Siesta parses JSON, text,
        // and images based on content type — and a resource will contain whatever the server happened to return, in a
        // parsed but unstructured form (string, dictionary, etc.). If you prefer to work with raw dictionaries instead
        // of models, no additional transformer config is necessary.
        //
        // If you do apply a path-based mapping like the ones above, then any request for that path that does not return
        // the expected type becomes an error. For example, "/users/foo" must return a JSON response because that's
        // what the User(json:) expects.
    }

    // MARK: Authentication

    func logIn(username username: String, password: String) {
        if let auth = "\(username):\(password)".dataUsingEncoding(NSUTF8StringEncoding) {
            basicAuthHeader = "Basic \(auth.base64EncodedStringWithOptions([]))"
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
            // Therefore, if your UI diligently observes all the resources it uses, this call prevents sensitive data
            // from lingering in the UI after logout.
        }
    }

    // MARK: Endpoints

    // You can turn your REST API into a nice Swift API using lightweight wrappers that return Siesta resources.
    //
    // Note that this class keeps its service private, making these methods the only entry points for the API.
    // You could also choose to subclass Service, which makes methods like service.resource(…) available to
    // your whole app. That approach is sometimes better for quick and dirty prototyping.

    func user(username: String) -> Resource {
        return service
            .resource("/users")
            .child(username.lowercaseString)
    }

    func repository(ownedBy login: String, named name: String) -> Resource {
        return service
            .resource("/repos")
            .child(login)
            .child(name)
    }

    func repository(repositoryModel: Repository) -> Resource {
        return repository(ownedBy: repositoryModel.owner.login, named: repositoryModel.name)
    }

    func currentUserStarred(repositoryModel: Repository) -> Resource {
        return service
            .resource("/user/starred")
            .child(repositoryModel.owner.login)
            .child(repositoryModel.name)
    }

    func setStarred(isStarred: Bool, repository repositoryModel: Repository) -> Request {
        let starredResource = currentUserStarred(repositoryModel)
        return starredResource
            .request(isStarred ? .PUT : .DELETE)
            .onSuccess { _ in
                starredResource.overrideLocalContent(isStarred)
                self.repository(repositoryModel).load()  // To update star count
            }
    }
}

private let SwiftyJSONTransformer =
    ResponseContentTransformer
        { JSON($0.content as AnyObject) }

private struct GithubErrorMessageExtractor: ResponseTransformer {
    func process(response: Response) -> Response {
        switch response {
            case .Success:
                return response

            case .Failure(var error):
                error.userMessage = error.jsonDict["message"] as? String ?? error.userMessage
                return .Failure(error)
        }
    }
}

private struct TrueIfResourceFoundTransformer: ResponseTransformer {
    func process(response: Response) -> Response {
        switch response {
            case .Success(var entity):
                entity.content = true  // Any success → true
                return logTransformation(
                    .Success(entity))

            case .Failure(let error):
                if var entity = error.entity where error.httpStatusCode == 404 {
                    entity.content = false  // 404 → false
                    return logTransformation(
                        .Success(entity))
                } else {
                    return .Failure(error)  // Any other error remains an error
                }
        }
    }
}
