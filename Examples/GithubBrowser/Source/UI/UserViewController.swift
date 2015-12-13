//
//  ViewController.swift
//  GithubBrowser
//
//  Created by Paul on 2015/7/7.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import UIKit
import Siesta

class UserViewController: UIViewController, UISearchBarDelegate, ResourceObserver {

    @IBOutlet weak var userInfoView: UIView!
    @IBOutlet weak var usernameLabel, fullNameLabel: UILabel!
    @IBOutlet weak var avatar: RemoteImageView!
    var statusOverlay = ResourceStatusOverlay()

    var repoListVC: RepositoryListViewController?

    var user: Resource? {
        didSet {
            oldValue?.removeObservers(ownedBy: self)
            oldValue?.cancelLoadIfUnobserved(afterDelay: 0.1)

            user?.addObserver(self)
                 .addObserver(statusOverlay, owner: self)
                 .loadIfNeeded()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        userInfoView.hidden = true
        statusOverlay.embedIn(self)
    }

    override func viewDidLayoutSubviews() {
        statusOverlay.positionToCover(userInfoView)
    }

    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        if let searchText = searchBar.text where !searchText.isEmpty {
            user = GithubAPI.user(searchText)
        }
    }

    func resourceChanged(resource: Resource, event: ResourceEvent) {
        userInfoView.hidden = (resource.latestData == nil)

        let user = resource.json
        usernameLabel.text = user["login"].string
        fullNameLabel.text = user["name"].string
        avatar.imageURL = user["avatar_url"].string

        repoListVC?.repoList = resource
            .optionalRelative(user["repos_url"].string)?
            .withParam("type", "all")
            .withParam("sort", "updated")
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "repoList" {
            repoListVC = segue.destinationViewController as? RepositoryListViewController
        }
    }
}
