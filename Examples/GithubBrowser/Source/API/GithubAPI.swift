//
//  GithubAPI.swift
//  GithubBrowser
//
//  Created by Paul on 2015/7/7.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import Siesta

let GithubAPI = _GithubAPI()

class _GithubAPI: Service {

    private init() {
        super.init(base: "https://api.github.com")
        
        #if DEBUG
            Siesta.enabledLogCategories = LogCategory.common
                // Also try:
                //   LogCategory.all
                //   [.Network]
                //   [.Network, .NetworkDetails]
        #endif
        
        configure {
            $0.config.headers["Authorization"] = self.basicAuthHeader
            $0.config.responseTransformers.add(GithubErrorMessageExtractor())
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
        return resource("users").child(username)
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
