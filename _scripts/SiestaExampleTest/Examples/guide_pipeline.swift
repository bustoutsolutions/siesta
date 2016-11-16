import Siesta

private
//══════ guide_pipeline:0 ══════
extension PipelineStageKey {
  static let
    munging   = PipelineStageKey(description: "munging"),
    twiddling = PipelineStageKey(description: "twiddling")
}
//════════════════════════════════════

func guide_pipeline(service: Service, resource: Resource) {
                                                                                                                                                                                                                        
    //══════ guide_pipeline:1 ══════
    service.configure {
      $0.pipeline.order = [.rawData, .munging, .twiddling, .cleanup]
    }
    //════════════════════════════════════
        
    //══════ guide_pipeline:2 ══════
    service.configure("/funky/**") {
      $0.pipeline[.parsing].removeTransformers()
    }
    //════════════════════════════════════
        
    //══════ guide_pipeline:3 ══════
    service.configureTransformer("/users/*") {
      User(json: $0.content)  // Input type inferred because User.init takes JSON
    }
    //════════════════════════════════════
        
    //══════ guide_pipeline:4 ══════
    service.configureTransformer("/users/*/repos") {
      ($0.content as JSON).arrayValue  // “as JSON” gives Siesta an explicit input type
        .map(Repository.init)          // Swift can infer that the output type is [Repository]
    }
    //════════════════════════════════════
        
    //══════ guide_pipeline:5 ══════
    let SwiftyJSONTransformer =
      ResponseContentTransformer
        { JSON($0.content as AnyObject) }
    //════════════════════════════════════
        
    //══════ guide_pipeline:6 ══════
    service.configure {
      $0.pipeline[.parsing].add(
        SwiftyJSONTransformer,
        contentTypes: ["*/json"])
    }
    //════════════════════════════════════
        
    //══════ guide_pipeline:7 ══════
    struct GithubErrorMessageExtractor: ResponseTransformer {
      func process(_ response: Response) -> Response {
        switch response {
          case .success:
            return response
    
          case .failure(var error):
            error.userMessage =
              error.jsonDict["message"] as? String ?? error.userMessage
            return .failure(error)
        }
      }
    }
    //════════════════════════════════════
        
    //══════ guide_pipeline:8 ══════
    service.configure {
      $0.pipeline[.cleanup].add(
        GithubErrorMessageExtractor())
    }
    //════════════════════════════════════
    
    /*                                                                                                                                                                                                            
    //══════ guide_pipeline:9 ══════
    // ☠☠☠ WRONG ☠☠☠
    Alamofire.request(.GET, "https://myapi.example/status")
      .responseJSON { /* stop activity indicator */ }
      .responseJSON { /* update UI */ }
      .responseJSON { /* play happy sound on success */ }
      .responseJSON { /* show error message */ }
    //════════════════════════════════════
    
    */

    let `self` = DummyObject()
                                                                                                                                                                                                                
    //══════ guide_pipeline:10 ══════
    // /* start/stop activity indicator */  →  _ in
    // /* update UI */                      →  _ in
    // /* play happy sound */               →  _ in
    // /* show error message */             →  _ in
    let resource = service.resource("/status")
    
    resource
      .addObserver(owner: self) { _ in }
      .addObserver(owner: self) { _ in }
    
    resource.load()
      .onSuccess { _ in }
      .onFailure { _ in }
    //════════════════════════════════════
    
}
