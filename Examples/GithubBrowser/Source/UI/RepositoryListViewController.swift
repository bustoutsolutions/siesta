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
    
    func resourceChanged(resource: Resource, event: ResourceEvent) {
        // Siesta’s typedContent() infers from the type of the repos property that reposResource should hold content
        // of type [Repository]. Our content tranformer configuation in GithubAPI makes this so. It is up to a Siesta
        // user to ensure that the transformer output and the expected content type always line up like this.
        
        repos = reposResource?.typedContent() ?? []
    }

    var repos: [Repository] = [] {
        didSet {
            tableView.reloadData()
        }
    }

    var statusOverlay = ResourceStatusOverlay()

    override func viewDidLoad() {
        super.viewDidLoad()

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
            cell.userLabel.text = repo.owner
            cell.repoLabel.text = repo.name
        }
        return cell
    }
}

class RepositoryTableViewCell: UITableViewCell {
    @IBOutlet weak var userLabel: UILabel!
    @IBOutlet weak var repoLabel: UILabel!
}
