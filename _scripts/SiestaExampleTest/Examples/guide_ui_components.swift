import Siesta
import SiestaUI
import UIKit

func guide_ui_components(service: Service, resource: Resource) {

                                                                                                                                                                                                                                
    //══════ guide_ui_components:0 ══════
    class ProfileViewController: UIViewController, ResourceObserver {
        @IBOutlet weak var nameLabel, favoriteColorLabel: UILabel!
        
        let statusOverlay = ResourceStatusOverlay()
    
        override func viewDidLoad() {
            super.viewDidLoad()
    
            statusOverlay.embed(in: self)
    
            MyAPI.profile
                .addObserver(self)
                .addObserver(statusOverlay)
        }
    
        override func viewDidLayoutSubviews() {
            statusOverlay.positionToCoverParent()
        }
        
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            MyAPI.profile.loadIfNeeded()
        }
    
        func resourceChanged(_ resource: Resource, event: ResourceEvent) {
            let json = JSON(resource.jsonDict)
            nameLabel.text = json["name"].string
            favoriteColorLabel.text = json["favoriteColor"].string
        }
    }
    //════════════════════════════════════
    
}
