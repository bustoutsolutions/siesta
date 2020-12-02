import UIKit
import Siesta
import Combine

class UserViewController: UIViewController, UISearchBarDelegate {

    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var userInfoView: UIView!
    @IBOutlet weak var usernameLabel, fullNameLabel: UILabel!
    @IBOutlet weak var avatar: RemoteImageView!

    var statusOverlay = ResourceStatusOverlay()

    var repoListVC: RepositoryListViewController?

    private let searchBarText = PassthroughSubject<String, Never>()
    private var subs = [AnyCancellable]()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = SiestaTheme.darkColor

        statusOverlay.embed(in: self)

        searchBar.becomeFirstResponder()

        GitHubAPI.isAuthenticatedPublisher
                .map { $0 ? "Log Out" : "Log In" }
                .sink { [unowned self] in self.loginButton.setTitle($0, for: .normal) }
                .store(in: &subs)

        loginButton.tapPublisher
                .withLatestFrom(GitHubAPI.isAuthenticatedPublisher)
                .sink { [unowned self] in
                    if $0 {
                        GitHubAPI.logOut()
                    }
                    else {
                        self.performSegue(withIdentifier: "login", sender: self.loginButton)
                    }
                }
                .store(in: &subs)

        let searchString = searchBarText
                .prepend("")
                .map { $0 == "" ? nil : $0 }
                .removeDuplicates()
                .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)

        /*
        About API classes:

        There are a couple of possibilities for your API methods:
        (1) as with non-reactive Siesta, return a Resource (or a Request)
        (2) return publishers - the result of Resource.statePublisher() or requestPublisher()

        (2) has the advantage of being strong typed, so you get to know more about your API from your method
        definitions. But you are stepping out of Siesta-world by doing this, and you lose the ability to do
        anything else Resource-related.

        For those with non-pedantic taste, you could use (2), but drop down to (1) for some methods as required.

        In this sample project we stick with (1). This is mainly to avoid rewriting GitHubAPI for every variant,
        but also because we want to use ResourceStatusOverlay. (It would be possible to write a ResourceStatusOverlay
        that understands streams of ResourceState, but here we just use a simple adapter that works with streams of Resource.)
        */
        let user: AnyPublisher<User?, Never> =
                // Look up the user by name, either when the search string changes or the login state changes. (We
                // want the latter in case the previous lookup failed because of api rate limits when not logged in.)
                //
                // Of course, this being Siesta, "look up" might just consist of getting the already-loaded resource
                // content. We trigger repeated lookups without fear.
                //
                // It works like this: combineLatest outputs another item, causing a new subscription to contentPublisher()
                // below, which in turn calls loadIfNeeded().
                //
                searchString.combineLatest(GitHubAPI.isAuthenticatedPublisher)
                        .map { searchString, _ -> Resource? in
                            if let searchString = searchString {
                                return GitHubAPI.user(searchString)
                            }
                            else {
                                return nil
                            }
                        }

                        // We have a stream of Resource? at the moment - the status overlay observes the Resource,
                        // displaying spinner, errors and the retry option...
                        .watchedBy(statusOverlay: statusOverlay)

                        // ... then we get the typed content (User - it's part of the `let user` declaration above).
                        // Finally, a Siesta+Combine operation!
                        //
                        // If we weren't using statusOverlay we might have called statePublisher() here instead of
                        // contentPublisher(), and done something with that to display progress and errors as well as the
                        // content.
                        .flatMapLatest { $0?.contentPublisher() ?? Just(nil).eraseToAnyPublisher() }
                        .eraseToAnyPublisher()

        searchString.combineLatest(user)
                .sink { [unowned self] searchString, user in
                    self.fullNameLabel.text = user?.name
                    self.avatar.imageURL = user?.avatarURL
                    self.usernameLabel.text = searchString == nil ? "Active Repositories" : user?.login
                }
                .store(in: &subs)

        // Configure the repo list with the repositories to display. It accepts Observable<Resource>, but could have
        // accepted Observable<[Repository]> - see the notes in RepositoryListViewController.
        repoListVC?.configure(repositories:
            searchString.combineLatest(user)
                .map { (searchString, user) -> Resource? in
                    if let user = user {
                        return GitHubAPI.user(user.login)
                                .optionalRelative(user.repositoriesURL)?
                                .withParam("sort", "updated")
                    }
                    else if searchString != nil {
                        return nil
                    }
                    else {
                        return GitHubAPI.activeRepositories
                    }
                }
                .eraseToAnyPublisher()
            )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setNeedsStatusBarAppearanceUpdate()

        CommentaryViewController.publishCommentary(
                """
                Stress test the live search above by rapidly deleting and retyping the same characters.
                Note how fast previously fetched data reappears. <b>Why so fast?</b>

                Unlike other networking libraries, Siesta can cache responses in their final, fully parsed, <b>app-specific
                form</b>. And it lets the app use stale cached data while <b>simultaneously</b> requesting an update.

                This example app has no special logic for caching, throttling, or preventing redundant network requests.
                That’s <b>all handled by Siesta</b>.

                On this screen, the user profile, avatars, and repo list come from separate cascading API calls.
                With traditional callback-based networking, this would be a <b>state nightmare</b>. Why? Well…

                How do you prevent all these views from <b>getting out of sync</b> as the user types?
                Even if responses for different repos come back late? Out of order?

                Siesta’s architecture provides an <b>elegant solution</b> to this problem.
                Its abstractions produce app code that is <b>simpler and less brittle</b>.
                """)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    override func viewDidLayoutSubviews() {
        statusOverlay.positionToCover(userInfoView)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "repos" {
            repoListVC = segue.destination as? RepositoryListViewController
        }
    }

    // CombineCocoa doesn't support UISearchBar (or any other delegate-based components) yet
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchBarText.send(searchText)
    }

    // Dummy actions just here for compatibility with the storyboard, which we share with the other implementations
    // of this controller.

    @IBAction func logInOrOut() { }
}