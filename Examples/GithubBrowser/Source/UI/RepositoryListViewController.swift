import UIKit
import Siesta

class RepositoryListViewController: UITableViewController, ResourceObserver {

    var reposResource: Resource? {
        didSet {
            oldValue?.removeObservers(ownedBy: self)

            reposResource?.addObserver(self)
                          .addObserver(statusOverlay, owner: self)
                          .loadIfNeeded()
        }
    }

    var repos: [Repository] = [] {
        didSet {
            tableView.reloadData()
        }
    }

    var statusOverlay = ResourceStatusOverlay()

    func resourceChanged(resource: Resource, event: ResourceEvent) {
        // Siesta’s typedContent() infers from the type of the repos property that reposResource should hold content
        // of type [Repository].

        repos = reposResource?.typedContent() ?? []
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = SiestaTheme.darkColor
        statusOverlay.embedIn(self)

        self.clearsSelectionOnViewWillAppear = false
    }

    override func viewDidLayoutSubviews() {
        statusOverlay.positionToCoverParent()
    }

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return repos.count ?? 0
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("repo", forIndexPath: indexPath)
        if let cell = cell as? RepositoryTableViewCell {
            let repo = repos[indexPath.row]
            cell.userLabel.text = repo.owner?.login
            cell.repoLabel.text = repo.name
            cell.starCountLabel.text = repo.starCount?.description

            // Note how powerful this next line is:
            //
            // • RemoteImageView calls loadIfNeeded() when we set imageURL, so this automatically triggers a network
            //   request for the image. However...
            // • loadIfNeeded() won’t make redundant requests, so no need to worry about whether this avatar is used in
            //   other table cells, or whether we’ve already requested it! Many cells sharing one image spawn one
            //   request. One response updates _all_ the cells that image.
            // • If imageURL was already set, RemoteImageView calls cancelLoadIfUnobserved() on the old image resource.
            //   This means that if the user is scrolling fast and table cells are being reused:
            //   - a request in progress gets cancelled
            //   - unless other cells are also waiting on the same image, in which case the request continues, and
            //   - an image that we’ve already fetch stay available in memory, fully parsed & ready for instant resuse.
            //
            // Finally, note that all of this nice behavior is not special magic that’s specific to images. These are
            // basic Siesta behaviors you can use for resources of any kind. Look at the RemoteImageView source code
            // and study how it uses the core Siesta API.

            cell.icon.imageURL = repo.owner?.avatarURL
        }
        return cell
    }

    override func tableView(tableView: UITableView, shouldHighlightRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return false
    }
}

class RepositoryTableViewCell: UITableViewCell {
    @IBOutlet weak var icon: RemoteImageView!
    @IBOutlet weak var userLabel: UILabel!
    @IBOutlet weak var repoLabel: UILabel!
    @IBOutlet weak var starCountLabel: UILabel!
}
