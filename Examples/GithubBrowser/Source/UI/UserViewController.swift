import UIKit
import Siesta

class UserViewController: UIViewController, UISearchBarDelegate, ResourceObserver {

    @IBOutlet weak var userInfoView: UIView!
    @IBOutlet weak var usernameLabel, fullNameLabel: UILabel!
    @IBOutlet weak var avatar: RemoteImageView!
    var statusOverlay = ResourceStatusOverlay()

    var repoListVC: RepositoryListViewController?

    var userResource: Resource? {
        didSet {
            oldValue?.removeObservers(ownedBy: self)
            oldValue?.cancelLoadIfUnobserved(afterDelay: 0.1)

            userResource?.addObserver(self)
                         .addObserver(statusOverlay, owner: self)
                         .loadIfNeeded()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        userInfoView.hidden = true
        statusOverlay.embedIn(self)
    }

    override func viewDidLayoutSubviews() {
        statusOverlay.positionToCover(userInfoView)
    }

    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        if let searchText = searchBar.text where !searchText.isEmpty {
            userResource = GithubAPI.user(searchText)
        }
    }

    func resourceChanged(resource: Resource, event: ResourceEvent) {
        let user: User? = userResource?.typedContent()
        
        userInfoView.hidden = (user == nil)
        
        usernameLabel.text = user?.login
        fullNameLabel.text = user?.name
        avatar.imageURL = user?.avatarURL

        repoListVC?.reposResource =
            userResource?
                .optionalRelative(user?.repositoriesURL)?
                .withParam("type", "all")
                .withParam("sort", "updated")
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "repos" {
            repoListVC = segue.destinationViewController as? RepositoryListViewController
        }
    }
}
