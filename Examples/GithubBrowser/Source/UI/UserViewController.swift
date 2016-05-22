import UIKit
import Siesta

class UserViewController: UIViewController, UISearchBarDelegate, ResourceObserver {

    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var userInfoView: UIView!
    @IBOutlet weak var usernameLabel, fullNameLabel: UILabel!
    @IBOutlet weak var avatar: RemoteImageView!
    var statusOverlay = ResourceStatusOverlay()

    var repoListVC: RepositoryListViewController?

    var userResource: Resource? {
        didSet {
            // One call to removeObservers() removes both self and statusOverlay as observers of the old resource,
            // since both observers are owned by self (see below).
            
            oldValue?.removeObservers(ownedBy: self)
            oldValue?.cancelLoadIfUnobserved(afterDelay: 0.1)
            
            // Adding ourselves as an observer triggers an immediate call to resourceChanged().
            
            userResource?.addObserver(self)
                         .addObserver(statusOverlay, owner: self)
                         .loadIfNeeded()
        }
    }

    func resourceChanged(resource: Resource, event: ResourceEvent) {
        // typedContent() infers that we want a User from context: showUser() expects one. Our content tranformer
        // configuation in GithubAPI makes it so that the userResource actually holds a User. It is up to a Siesta
        // client to ensure that the transformer output and the expected content type line up like this.
        // 
        // If there were a type mismatch, typedContent() would return nil. (We could also provide a default value with
        // the ifNone: param.)
        
        showUser(userResource?.typedContent())
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = SiestaTheme.darkColor
        userInfoView.hidden = true
        
        statusOverlay.embedIn(self)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        setNeedsStatusBarAppearanceUpdate()
        updateLoginButton()
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent;
    }

    override func viewDidLayoutSubviews() {
        statusOverlay.positionToCover(userInfoView)
    }

    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        if let searchText = searchBar.text where !searchText.isEmpty {
            
            // Setting userResource triggers a load and display of the new user data. Note that Siesta’s redunant
            // request elimination and model caching make it reasonable to do this on every keystroke.
            
            userResource = GithubAPI.user(searchText)
        }
    }

    func showUser(user: User?) {
        userInfoView.hidden = (user == nil)
        
        // It's often easiest to make the same code path handle both the “data” and “no data” states.
        // If this UI update were more expensive, we could choose to do it only on ObserverAdded or NewData.
        
        usernameLabel.text = user?.login
        fullNameLabel.text = user?.name
        avatar.imageURL = user?.avatarURL
        
        // Setting the reposResource property of the embedded VC triggers load & display of the user’s repos.

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
    
    @IBAction func logInOrOut() {
        if(GithubAPI.isAuthenticated) {
            GithubAPI.logOut()
            updateLoginButton()
        } else {
            performSegueWithIdentifier("login", sender: loginButton)
        }
    }
    
    private func updateLoginButton() {
        loginButton.setTitle(GithubAPI.isAuthenticated ? "Log Out" : "Log In", forState: .Normal)
        userResource?.loadIfNeeded()
    }
}
