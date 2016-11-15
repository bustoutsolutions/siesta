import UIKit
import Siesta

class UserViewController: UIViewController, UISearchBarDelegate, ResourceObserver {

    // MARK: UI Elements

    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var userInfoView: UIView!
    @IBOutlet weak var usernameLabel, fullNameLabel: UILabel!
    @IBOutlet weak var avatar: RemoteImageView!

    var statusOverlay = ResourceStatusOverlay()

    // MARK: Resources

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

    func resourceChanged(_ resource: Resource, event: ResourceEvent) {
        // typedContent() infers that we want a User from context: showUser() expects one. Our content tranformer
        // configuation in GitHubAPI makes it so that the userResource actually holds a User. It is up to a Siesta
        // client to ensure that the transformer output and the expected content type line up like this.
        //
        // If there were a type mismatch, typedContent() would return nil. (We could also provide a default value with
        // the ifNone: param.)

        showUser(userResource?.typedContent())
    }

    // MARK: Setup

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = SiestaTheme.darkColor

        statusOverlay.embed(in: self)
        showUser(nil)

        searchBar.becomeFirstResponder()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setNeedsStatusBarAppearanceUpdate()
        updateLoginButton()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override func viewDidLayoutSubviews() {
        statusOverlay.positionToCover(userInfoView)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "repos" {
            repoListVC = segue.destination as? RepositoryListViewController
        }
    }

    // MARK: User & repo list

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if let searchText = searchBar.text, !searchText.isEmpty {

            // Setting userResource triggers a load and display of the new user data. Note that Siesta’s redunant
            // request elimination and model caching make it reasonable to do this on every keystroke.

            userResource = GitHubAPI.user(searchText)
        } else {
            userResource = nil
            showUser(nil)
        }
    }

    func showUser(_ user: User?) {
        // It's often easiest to make the same code path handle both the “data” and “no data” states.
        // If this UI update were more expensive, we could choose to do it only on ObserverAdded or NewData.

        fullNameLabel.text = user?.name
        avatar.imageURL = user?.avatarURL

        // Here the “data” and “no data” states diverge enough that it’s worth taking two separate code paths.
        // Note, however, that declaring these two variables without initializers guarantees that they’ll both be
        // set in either branch before they’re used.

        let title: String?
        let repositoriesResource: Resource?

        if let user = user {
            title = user.login
            repositoriesResource =
                userResource?
                    .optionalRelative(user.repositoriesURL)?
                    .withParam("sort", "updated")
        } else if userResource != nil {
            title = nil
            repositoriesResource = nil
        } else {
            title = "Active Repositories"
            repositoriesResource = GitHubAPI.activeRepositories
        }

        // Setting the repositoriesResource property of the embedded VC triggers load & display of the user’s repos.

        repoListVC?.repositoriesResource = repositoriesResource
        usernameLabel.text = title
    }

    // MARK: Log in / out

    @IBAction func logInOrOut() {
        if(GitHubAPI.isAuthenticated) {
            GitHubAPI.logOut()
            updateLoginButton()
        } else {
            performSegue(withIdentifier: "login", sender: loginButton)
        }
    }

    private func updateLoginButton() {
        loginButton.setTitle(GitHubAPI.isAuthenticated ? "Log Out" : "Log In", for: UIControlState())
        userResource?.loadIfNeeded()
    }
}
