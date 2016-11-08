import Siesta

func guide_objc(service: Service, resource: Resource) {                                                                                                        
    //══════ guide_objc:0 ══════
    class MyAPI: Service {
        public static let instance = MyAPI(baseURL: "https://api.example.com")
    }
    //════════════════════════════════════
    
    /**                                                                                                            
    //══════ guide_objc:1 ══════
    resource.request(.flargle)
    //════════════════════════════════════
    
    */
                                                                                                                    
    //══════ guide_objc:2 ══════
    // … → return
    resource.request(.post, json: ["color": "green"])
      .onCompletion { info in
        switch info.response {
          case .success(let data):
            return
          
          case .failure(let error):
            return
        }
      }
    //════════════════════════════════════
    
}
