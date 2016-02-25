import Siesta
import SwiftyJSON

// Depending on your taste, a Service can be a global var, a static var singleton, or a piece of more carefully
// controlled shared state passed between pieces of the app.

let GithubAPI = _GithubAPI()

class _GithubAPI {

    private let service = Service(baseURL: "https://api.github.com")

    private init() {
        #if DEBUG
            Siesta.enabledLogCategories = LogCategory.detailed
        #endif
        
        // Global configuration

        service.configure {
            $0.config.headers["Authorization"] = self.basicAuthHeader
            $0.config.responseTransformers.add(GithubErrorMessageExtractor())
            $0.config.responseTransformers.add(SwiftyJSONTransformer, contentTypes: ["*/json"])
        }
        
        // Mapping from specific paths to models

        service.configureTransformer("/users/*") {
            User(json: $0.content)
        }
        
        service.configureTransformer("/users/*/repos") {
            ($0.content as JSON).arrayValue.map(Repository.init)
        }
        
        // Note that you can use Siesta without these sorts of model mappings. By default, Siesta parses JSON, text,
        // and images based on content type — and a resource will contain whatever the server happened to return, in a
        // parsed but unstructured form (string, dictionary, etc.).
        //
        // If you do apply a path-based mapping like the ones above, then any request for that path that does not return
        // the expected type becomes an error. For example, "/users/foo" must return a JSON response because that's
        // what the User(json:) expects.
    }
    
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
            service.invalidateConfiguration()  // So that future requests for existing resources pick up config change
            service.wipeResources()            // Scrub all unauthenticated data
        }
    }

    // Resource convenience accessors

    func user(username: String) -> Resource {
        return service.resource("users").child(username.lowercaseString)
    }
}

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

private let SwiftyJSONTransformer =
    ResponseContentTransformer(skipWhenEntityMatchesOutputType: false)
        { JSON($0.content as AnyObject) }
