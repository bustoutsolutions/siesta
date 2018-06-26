import Siesta
import UIKit

class guide_observers_0: ResourceObserver {

    func resourceChanged(_ resource: Resource, event: ResourceEvent) { }

    func stuff(resource: Resource) {

        //══════ guide_observers:0 ══════
        resource.addObserver(self)
        //════════════════════════════════════

        //══════ guide_observers:1 ══════
        // … →
        resource.addObserver(owner: self) {
            [weak self] resource, event in

        }
        //════════════════════════════════════

        var nameLabel: UILabel!
        var favoriteColorLabel: UILabel!
        var errorLabel: UILabel!

        //══════ guide_observers:2 ══════
        func resourceChanged(_ resource: Resource, event: ResourceEvent) {
            // The convenience .jsonDict accessor returns empty dict if no
            // data, so the same code can both populate and clear fields.
            let json = resource.jsonDict
            nameLabel.text = json["name"] as? String
            favoriteColorLabel.text = json["favoriteColor"] as? String

            errorLabel.text = resource.latestError?.userMessage
        }
        //════════════════════════════════════

    }
}

class guide_observers_1: ResourceObserver {
    //══════ guide_observers:3 ══════
    func resourceChanged(_ resource: Resource, event: ResourceEvent) {
        if case .newData = event {
            // Do expensive update
        }
    }
    //════════════════════════════════════

}

class guide_observers_2: ResourceObserver {
    var displayedEtag: String?

    //══════ guide_observers:4 ══════
    func resourceChanged(_ resource: Resource, event: ResourceEvent) {
        if displayedEtag != resource.latestData?.etag {
            displayedEtag = resource.latestData?.etag
            // Do expensive update
        }
    }
    //════════════════════════════════════

}
