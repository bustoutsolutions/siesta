import UIKit
import Siesta

class RepositoryListViewController: UITableViewController, ResourceObserver {

    // MARK: Interesting Siesta stuff

    var repositoriesResource: Resource? {
        didSet {
            oldValue?.removeObservers(ownedBy: self)

            repositoriesResource?
                .addObserver(self)
                .addObserver(statusOverlay, owner: self)
                .loadIfNeeded()
        }
    }

    var repositories: [Repository] = [] {
        didSet {
            tableView.reloadData()
        }
    }

    var statusOverlay = ResourceStatusOverlay()

    func resourceChanged(_ resource: Resource, event: ResourceEvent) {
        // Siesta’s typedContent() infers from the type of the repositories property that
        // repositoriesResource should hold content of type [Repository].

        repositories = repositoriesResource?.typedContent() ?? []
    }

    // MARK: Standard table view stuff

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = SiestaTheme.darkColor
        statusOverlay.embed(in: self)
    }

    override func viewDidLayoutSubviews() {
        statusOverlay.positionToCoverParent()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return repositories.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "repo", for: indexPath)
        if let cell = cell as? RepositoryTableViewCell {
            cell.repository = repositories[(indexPath as IndexPath).row]
        }
        return cell
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "repoDetail" {
            if let repositoryVC = segue.destination as? RepositoryViewController,
               let cell = sender as? RepositoryTableViewCell {

                repositoryVC.repositoryResource =
                    repositoriesResource?.optionalRelative(
                        cell.repository?.url)
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
