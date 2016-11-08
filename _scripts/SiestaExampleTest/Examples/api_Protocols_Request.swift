import Siesta

struct ThingThatNeedsCleanup {
    func cleanUp() { }
}

func api_Protocols_Request(request: Request) {

    let underlyingRequest = request
                                                                                                    
    //══════ api_Protocols_Request:0 ══════
    // …whenCompleted… → return .useThisResponse
    let chainedRequest = underlyingRequest.chained {
      response in return .useThisResponse
    }
    //════════════════════════════════════
    
    print(chainedRequest)
                                                                                                            
    //══════ api_Protocols_Request:1 ══════
    // …some logic… → _ in return .useThisResponse
    let foo = ThingThatNeedsCleanup()
    request
      .chained { _ in return .useThisResponse }           // May not be called if chain is cancelled
      .onCompletion{ _ in foo.cleanUp() } // Guaranteed to be called exactly once
    //════════════════════════════════════
    
}
