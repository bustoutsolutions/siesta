import Siesta
import UIKit

private let someResource = Service().resource("")

class guide_memory: ResourceObserver {
                                                                                                                                                                                            
    //══════ guide_memory:0 ══════
    // override → func resourceChanged(_ resource: Resource, event: ResourceEvent) { }; override
    // … →
    class ProfileViewController: UIViewController, ResourceObserver {
            
        func resourceChanged(_ resource: Resource, event: ResourceEvent) { }; override func viewDidLoad() {
            
            someResource.addObserver(self)
        }
    }
    //════════════════════════════════════
    
    let someViewController = ProfileViewController()
    
    func resourceChanged(_ resource: Resource, event: ResourceEvent) { }
                                                                                                                                                                                                
    //══════ guide_memory:3 ══════
    // … →
    var displayedResource: Resource? {
        didSet {
            // This removes both the observers added below,
            // because they are both owned by self.
            oldValue?.removeObservers(ownedBy: self)
    
            displayedResource?
                .addObserver(self)
                .addObserver(owner: self) { resource, event in  }
                .loadIfNeeded()
        }
    }
    //════════════════════════════════════
    
    struct MyLittleGlueObject: ResourceObserver {
        func resourceChanged(_ resource: Resource, event: ResourceEvent) { }
    }

    func things() {                                                                                                                                                                                                                                                                                                                                                                                        
        //══════ guide_memory:1 ══════
        someResource.addObserver(MyLittleGlueObject(), owner: self)
        //════════════════════════════════════
                
        //══════ guide_memory:2 ══════
        someResource.addObserver(owner: someViewController) {
            resource, event in
            print("Received \(event) for \(resource)")
        }
        //════════════════════════════════════
        
    }
}
