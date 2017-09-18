import Siesta

enum guide_configuration_0 {
                                                                                                                                                                                                            
    //══════ guide_configuration:0 ══════
    class MyAPI: Service {
      init() {
        super.init(baseURL: "https://api.example.com")
    
        // Global default headers
        configure {
          $0.headers["X-App-Secret"] = "2g3h4bkv234"
          $0.headers["User-Agent"] = "MyAwesomeApp 1.0"
        }
      }
    }
    //════════════════════════════════════
    
}

enum guide_configuration_1 {                                                                                                                                                                                                        
    //══════ guide_configuration:4 ══════
    class MyAPI: Service {
      var authToken: String? {
        didSet {
          configure {  // 😱😱😱 WRONG 😱😱😱
            $0.headers["X-HappyApp-Auth-Token"] = self.authToken
          }
        }
      }
    }
    //════════════════════════════════════
    
}

enum guide_configuration_2 {                                                                                                                                                                                                        
    //══════ guide_configuration:5 ══════
    // … →
    class MyAPI: Service {
      init() {
        super.init()
        
        // Call configure() only once during Service setup
        configure {
          $0.headers["X-HappyApp-Auth-Token"] = self.authToken  // NB: If service isn’t a singleton, use weak self
        }
      }
    
      
    
      var authToken: String? {
        didSet {
          // Rerun existing configuration closure using new value
          invalidateConfiguration()
    
          // Wipe any cached state if auth token changes
          wipeResources()
        }
      }
    }
    //════════════════════════════════════
    
}

enum guide_configuration_3 {
    class MyAPI: Service {
        var tokenCreationResource: Resource {
            return resource("/token")
        }
        
        func userAuthData() -> [String:String] {
            return [:]
        }
                                                                                                                                                                                                                                                                                                                                                                                                                        
        //══════ guide_configuration:7 ══════
        // ... → super.init()
        var authToken: String??
        
        init() {
          super.init()
          configure("**", description: "auth token") {
            if let authToken = self.authToken {
              $0.headers["X-Auth-Token"] = authToken         // Set the token header from a var that we can update
            }
            $0.decorateRequests {
              self.refreshTokenOnAuthFailure(request: $1)
            }
          }
        }
        
        // Refactor away this pyramid of doom however you see fit
        func refreshTokenOnAuthFailure(request: Request) -> Request {
          return request.chained {
            guard case .failure(let error) = $0.response,  // Did request fail…
              error.httpStatusCode == 401 else {           // …because of expired token?
                return .useThisResponse                    // If not, use the response we got.
            }
        
            return .passTo(
              self.createAuthToken().chained {             // If so, first request a new token, then:
                if case .failure = $0.response {           // If token request failed…
                  return .useThisResponse                  // …report that error.
                } else {
                  return .passTo(request.repeated())       // We have a new token! Repeat the original request.
                }
              }
            )
          }
        }
        
        func createAuthToken() -> Request {
          return tokenCreationResource
            .request(.post, json: userAuthData())
            .onSuccess {
              self.authToken = $0.jsonDict["token"] as? String  // Store the new token, then…
              self.invalidateConfiguration()                    // …make future requests use it
            }
          }
        }
        //════════════════════════════════════
        
}

class guide_configuration_snippets: Service {
    func go() {
                                                                                                                                                                                                                                                                                                                                                                                                                    
        //══════ guide_configuration:1 ══════
        configure("/volcanos/*/status") {
          $0.expirationTime = 0.5  // default is 30 seconds
        }
        //════════════════════════════════════
                
        //══════ guide_configuration:2 ══════
        configure(whenURLMatches: { $0.scheme == "https" }) {
          $0.headers["X-App-Secret"] = "2g3h4bkv234"
        }
        //════════════════════════════════════
                
        //══════ guide_configuration:3 ══════
        configure {
          $0.headers["User-Agent"] = "MyAwesomeApp 1.0"
          $0.headers["Accept"] = "application/json"
        }
        
        configure("/**/knob") {
          $0.headers["Accept"] = "doorknob/round, doorknob/handle, */*"
        }
        //════════════════════════════════════
        
        let authenticationResource = resource("/auth")
        func showLoginScreen() { }
                                                                                                                                                                                                                                                                                                                                                                                                                        
        //══════ guide_configuration:6 ══════
        let authURL = authenticationResource.url
        
        configure(
            whenURLMatches: { $0 != authURL },         // For all resources except auth:
            description: "catch auth failures") {
        
          $0.decorateRequests { _, req in
            req.onFailure { error in                   // If a request fails...
              if error.httpStatusCode == 401 {         // ...with a 401...
                showLoginScreen()                      // ...then prompt the user to log in
              }
            }
          }
        }
        //════════════════════════════════════
        
    }
}
