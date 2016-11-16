import Siesta

class api_Structs_RequestError_Cause: Service {
    func go() {                                                                                                                                            
    //══════ api_Structs_RequestError_Cause:0 ══════
    // ... → }}; private
    configure {
      $0.pipeline[.parsing].add(GarbledResponseHandler())
    }
    
    }}; private
    
    struct GarbledResponseHandler: ResponseTransformer {
      func process(_ response: Response) -> Response {
        switch response {
          case .success:
            return response
    
          case .failure(let error):
            if error.cause is RequestError.Cause.InvalidTextEncoding {
              return .success(Entity<Any>(
                content: "Nothingness. Tumbleweeds. The Void.",
                contentType: "text/string"))
            } else {
              return response
            }
        }
      }
    }
    //════════════════════════════════════
    
