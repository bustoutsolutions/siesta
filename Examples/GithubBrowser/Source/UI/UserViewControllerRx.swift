import UIKit
import Siesta
import RxSwift
import RxCocoa
import RxOptional

class UserViewController: UIViewController, UISearchBarDelegate /* the latter only for storyboard compatibility */ {

    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var userInfoView: UIView!
    @IBOutlet weak var usernameLabel, fullNameLabel: UILabel!
    @IBOutlet weak var avatar: RemoteImageView!

    var statusOverlay = ResourceStatusOverlay()

    var repoListVC: RepositoryListViewController?

    private var disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = SiestaTheme.darkColor

        statusOverlay.embed(in: self)

        searchBar.becomeFirstResponder()

        GitHubAPI.isAuthenticatedObservable
                .map { $0 ? "Log Out" : "Log In" }
                .bind(to: loginButton.rx.title(for: .normal))
                .disposed(by: disposeBag)

        loginButton.rx.tap
                .withLatestFrom(GitHubAPI.isAuthenticatedObservable)
                .bind { [unowned self] in
                    if $0 {
                        GitHubAPI.logOut()
                    }
                    else {
                        self.performSegue(withIdentifier: "login", sender: self.loginButton)
                    }
                }
                .disposed(by: disposeBag)

        let searchString = searchBar.rx.text
                .map { $0 == "" ? nil : $0 }
                .distinctUntilChanged()
                .debounce(.milliseconds(300), scheduler: MainScheduler.instance)


        /*
        About API classes:

        There are a couple of possibilities for your API methods:
        (1) as with non-reactive Siesta, return a Resource (or a Request)
        (2) return observables - the result of Resource.rx.state() or rx.request()

        (2) has the advantage of being strong typed, so you get to know more about your API from your method
        definitions. But you are stepping out of Siesta-world by doing this, and you lose the ability to do
        anything else Resource-related.

        For those with non-pedantic taste, you could use (2), but drop down to (1) for some methods as required.

        In this sample project we stick with (1). This is mainly to avoid rewriting GitHubAPI for every variant,
        but also because we want to use ResourceStatusOverlay. (It would be possible to write a ResourceStatusOverlay
        that understands streams of ResourceState, but here we just use a simple adapter that works with streams of Resource.)
        */
        let user: Observable<User?> =
                // Look up the user by name, either when the search string changes or the login state changes. (We
                // want the latter in case the previous lookup failed because of api rate limits when not logged in.)
                //
                // Of course, this being Siesta, "look up" might just consist of getting the already-loaded resource
                // content. We trigger repeated lookups without fear.
                //
                // It works like this: combineLatest outputs another item, causing a new subscription to rx.content()
                // below, which in turn calls loadIfNeeded().
                //
                Observable.combineLatest(searchString, GitHubAPI.isAuthenticatedObservable)
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
                        // Finally, a Siesta+Rx operation!
                        // If we weren't using statusOverlay we might have called state() instead of content() and done
                        // something with that to display progress and errors as well as the content.
                        .flatMapLatest { $0?.rx.content() ?? .just(nil) }

        Observable.combineLatest(searchString, user)
                .bind { [unowned self] searchString, user in
                    self.fullNameLabel.text = user?.name
                    self.avatar.imageURL = user?.avatarURL
                    self.usernameLabel.text = searchString == nil ? "Active Repositories" : user?.login
                }
                .disposed(by: disposeBag)

        // Configure the repo list with the repositories to display. It accepts Observable<Resource>, but could have
        // accepted Observable<[Repository]> - see the notes in RepositoryListViewController.
        repoListVC?.configure(repositories:
            Observable.combineLatest(searchString, user)
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

    // Dummy actions just here for compatibility with the storyboard, which we share with the other implementations
    // of this controller.

    @IBAction func logInOrOut() { }
}