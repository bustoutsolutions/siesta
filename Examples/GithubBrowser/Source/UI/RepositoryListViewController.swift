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
            cell.userLabel.text = repo.owner
            cell.repoLabel.text = repo.name
        }
        return cell
    }
    
    override func tableView(tableView: UITableView, shouldHighlightRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return false
    }
}

class RepositoryTableViewCell: UITableViewCell {
    @IBOutlet weak var userLabel: UILabel!
    @IBOutlet weak var repoLabel: UILabel!
}
