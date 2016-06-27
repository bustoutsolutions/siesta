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
            User(json: $0.content)  // Input type inferred because User.init takes JSON
        }
        
        service.configureTransformer("/users/*/repos") {
            ($0.content as JSON).arrayValue.map(Repository.init)  // “as JSON” gives Siesta an explicit input type
        }
        
        // Note that you can use Siesta without these sorts of model mappings. By default, Siesta parses JSON, text,
        // and images based on content type — and a resource will contain whatever the server happened to return, in a
        // parsed but unstructured form (string, dictionary, etc.).
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

    // MARK: Resource convenience accessors
    
    // A set of lightweight wrappers that return Siesta resources turn your REST API into a nice Swift API.

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
