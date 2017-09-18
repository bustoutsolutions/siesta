import Siesta

func guide_security(service: Service, resource: Resource) {
                                                                                                                                                                                    
    //══════ guide_security:0 ══════
    // ... → super.init()
    class MyAPI: Service {
        init() {
            super.init()
    
            configure { $0.headers["Authorization"] = self.authHeader }
        }
    
        var authHeader: String? {
            didSet {
                // Clear any cached data now that auth has changed
                wipeResources()
    
                // Force resources to recompute headers next time they’re fetched
                invalidateConfiguration()
            }
        }
    }
    //════════════════════════════════════
    
    let myAPI = MyAPI()
    
    let authHeaderFromSuccessfulAuthRequest = "foo"                                                                                                                                                                            
    //══════ guide_security:1 ══════
    myAPI.authHeader = authHeaderFromSuccessfulAuthRequest
    //════════════════════════════════════
        
    //══════ guide_security:2 ══════
    myAPI.authHeader = nil
    //════════════════════════════════════
    
    let authToken = "foo"                                                                                                                                                                                
    //══════ guide_security:3 ══════
    service.configure("**", description: "auth token") {
      $0.headers["X-Auth-Token"] = authToken
    }
    //════════════════════════════════════
    
    struct UnauthorizedServer: Error { }
                                                                                                                                                                                        
    //══════ guide_security:4 ══════
    service.configure(whenURLMatches: { $0.host != "api.example.com" }) {
      $0.decorateRequests {
        _,_ in Resource.failedRequest(
          RequestError(
            userMessage: "Attempted to connect to unauthorized server",
            cause: UnauthorizedServer()))
      }
    }
    //════════════════════════════════════
    
    class MyCustomSessionPinningDelegate: NSObject, URLSessionDelegate { }
                                                                                                                                                                                        
    //══════ guide_security:5 ══════
    let certificatePinningSession = URLSession(
        configuration: URLSessionConfiguration.ephemeral,
        delegate: MyCustomSessionPinningDelegate(),
        delegateQueue: nil)
    let myService = Service(baseURL: "http://what.ever", networking: certificatePinningSession)
    //════════════════════════════════════
    
    print(myService)
    
}
