//
//  RepositoryListViewController.swift
//  GithubBrowser
//
//  Created by Paul on 2015/7/17.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import UIKit
import Siesta
import SwiftyJSON

class RepositoryListViewController: UITableViewController, ResourceObserver {

    var repoList: Resource? {
        didSet {
            oldValue?.removeObservers(ownedBy: self)
            repoList?.addObserver(self)
                     .addObserver(statusOverlay, owner: self)
                     .loadIfNeeded()
        }
    }

    var statusOverlay = ResourceStatusOverlay()
    
    func resourceChanged(resource: Siesta.Resource, event: Siesta.ResourceEvent) {
        tableView.reloadData()
    }

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
        return repoList?.jsonArray.count ?? 0
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("repo", forIndexPath: indexPath)
        if let cell = cell as? RepositoryTableViewCell, let repoList = repoList {
            let repo = JSON(repoList.jsonArray)[indexPath.row]
            cell.userLabel.text = repo["owner"]["login"].string
            cell.repoLabel.text = repo["name"].string
        }
        return cell
    }
}

class RepositoryTableViewCell: UITableViewCell {
    @IBOutlet weak var userLabel: UILabel!
    @IBOutlet weak var repoLabel: UILabel!
}
