import Siesta
import SwiftyJSON

let GithubAPI = _GithubAPI()

class _GithubAPI {

    private let service = Service(baseURL: "https://api.github.com")

    private init() {
        #if DEBUG
            Siesta.enabledLogCategories = LogCategory.detailed
        #endif

        service.configure {
            $0.config.headers["Authorization"] = self.basicAuthHeader
            $0.config.responseTransformers.add(GithubErrorMessageExtractor())
            $0.config.responseTransformers.add(SwiftyJSONTransformer, contentTypes: ["*/json"])
        }

        service.configureTransformer("/users/*") {
            return User(json: $0.content)
        }

        service.configureTransformer("/users/*/repos") {
            (content: JSON, _) in
            return content.arrayValue.map(Repository.init)
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
        return service.resource("users").child(username)
    }
}

private struct GithubErrorMessageExtractor: ResponseTransformer {
    func process(response: Response) -> Response {
        switch response {
            case .Success:
                return response

            case .Failure(var error):
                error.userMessage = error.json["message"].string ?? error.userMessage
                return .Failure(error)
        }
    }
}

private let SwiftyJSONTransformer =
    ResponseContentTransformer(skipWhenEntityMatchesOutputType: false)
        { JSON($0.content as AnyObject) }
