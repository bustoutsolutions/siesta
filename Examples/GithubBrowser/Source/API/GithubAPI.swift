import Siesta
import SwiftyJSON

// Depending on your taste, a Service can be a global var, singleton, or a piece of more carefully controlled shared
// state passed between pieces of the app.

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
    }

    private var basicAuthHeader: String? {
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
