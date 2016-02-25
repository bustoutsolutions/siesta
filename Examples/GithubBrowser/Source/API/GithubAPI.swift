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

    private var basicAuthHeader: String? {
        // Your auth config will probably depend on a user authenticating themselves, and thus change over time.
        // Be sure to call invalidateConfiguration() when the credentials change, and wipeResources() when a user
        // logs out (to flush an cached authorization-based data).
        
        let env = NSProcessInfo.processInfo().environment
        if let username = env["GITHUB_USER"],
           let password = env["GITHUB_PASS"],
           let auth = "\(username):\(password)".dataUsingEncoding(NSUTF8StringEncoding) {
            return "Basic \(auth.base64EncodedStringWithOptions([]))"
        } else {
            return nil
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
