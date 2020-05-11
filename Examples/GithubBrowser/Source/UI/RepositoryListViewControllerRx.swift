import UIKit
import Siesta
import RxSwift

class RepositoryListViewController: UITableViewController {

    private var statusOverlay = ResourceStatusOverlay()
    private var disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = SiestaTheme.darkColor
        statusOverlay.embed(in: self)

        // Standard table view stuff we don't want here (we're sharing the storyboard with the other examples)
        tableView.dataSource = nil
        tableView.delegate = nil
    }

    override func viewDidLayoutSubviews() {
        statusOverlay.positionToCoverParent()
    }

    /**
    The input to this class - the repositories to display.

    Whether it's better to pass in a resource or an observable here is much the same argument as whether to define
    APIs in terms of resources or observables. See UserViewController for a discussion about that.
    */
    func configure(repositories: Observable<Resource? /* [Repository] */>) {
        /*
        Oh hey, in the next small handful of lines, let's:
        - make an api call if necessary to fetch the latest repo list we're to show
        - display progress and errors while doing that, and
        - populate the table.
        */
        repositories
                .watchedBy(statusOverlay: statusOverlay)
                .flatMapLatest { resource -> Observable<[Repository]> in
                    resource?.rx.content() ?? .just([])
                }
                .bind(to: tableView.rx.items(cellIdentifier: "repo", cellType: RepositoryTableViewCell.self)) { 
                    (row, repo, cell) in
                    cell.repository = repo
                }
                .disposed(by: disposeBag)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "repoDetail" {
            if let repositoryVC = segue.destination as? RepositoryViewController,
               let cell = sender as? RepositoryTableViewCell {

                if let repo = cell.repository {
                    repositoryVC.repositoryResource = .just(GitHubAPI.repository(repo))
                }
            }
        }
    }
}

class RepositoryTableViewCell: UITableViewCell {
    @IBOutlet weak var icon: RemoteImageView!
    @IBOutlet weak var userLabel: UILabel!
    @IBOutlet weak var repoLabel: UILabel!
    @IBOutlet weak var starCountLabel: UILabel!

    var repository: Repository? {
        didSet {
            userLabel.text = repository?.owner.login
            repoLabel.text = repository?.name
            starCountLabel.text = repository?.starCount?.description

            // Note how powerful this next line is:
            //
            // • RemoteImageView calls loadIfNeeded() when we set imageURL, so this automatically triggers a network
            //   request for the image. However...
            //
            // • loadIfNeeded() won’t make redundant requests, so no need to worry about whether this avatar is used in
            //   other table cells, or whether we’ve already requested it! Many cells sharing one image spawn one
            //   request. One response updates _all_ the cells that image.
            //
            // • If imageURL was already set, RemoteImageView calls cancelLoadIfUnobserved() on the old image resource.
            //   This means that if the user is scrolling fast and table cells are being reused:
            //
            //   - a request in progress gets cancelled
            //   - unless other cells are also waiting on the same image, in which case the request continues, and
            //   - an image that we’ve already fetch stay available in memory, fully parsed & ready for instant resuse.
            //
            // Finally, note that all of this nice behavior is not special magic that’s specific to images. These are
            // basic Siesta behaviors you can use for resources of any kind. Look at the RemoteImageView source code
            // and study how it uses the core Siesta API.

            icon.imageURL = repository?.owner.avatarURL
        }
    }
}
