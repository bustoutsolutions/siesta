import Siesta
import UIKit

class UIDoorknob { }
let placeholderKnob = UIDoorknob()

//══════ api_Protocols_TypedContentAccessors:2 ══════
extension TypedContentAccessors {
  var doorknob: UIDoorknob {
    return typedContent(ifNone: placeholderKnob)
  }
}
//════════════════════════════════════

func api_Protocols_TypedContentAccessors(service: Service, resource: Resource) {                                                                                                                                                                                    
    //══════ api_Protocols_TypedContentAccessors:0 ══════
    // resource. → _ = resource.
    // (_ = resource. → _ = (resource.
    _ = resource.latestData?.content as? String
    _ = (resource.latestError?.entity?.content as? [String:AnyObject])?["error.detail"]
    //════════════════════════════════════
        
    //══════ api_Protocols_TypedContentAccessors:1 ══════
    // resource. → _ = resource.
    _ = resource.text
    _ = resource.latestError?.jsonDict["error.detail"]
    //════════════════════════════════════
        
    //══════ api_Protocols_TypedContentAccessors:3 ══════
    let image = resource.typedContent(ifNone: UIImage(named: "placeholder.png"))
    //════════════════════════════════════
        
    //══════ api_Protocols_TypedContentAccessors:4 ══════
    // ... →
    func showUser(_ user: User?) {
      
    }
    
    showUser(resource.typedContent())  // Infers that desired type is User
    //════════════════════════════════════
    
}
