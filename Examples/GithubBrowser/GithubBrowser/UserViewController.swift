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
    var repoListVC: RepositoryListViewController?
    
    var statusOverlay = ResourceStatusOverlay()
    
    var user: Resource?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        userInfoView.hidden = true
        
        statusOverlay.embedIn(self)
    }
    
    override func viewDidLayoutSubviews() {
        statusOverlay.positionToCover(userInfoView)
    }
    
    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        user?.removeObservers(ownedBy: self)
        user = nil
        
        if let searchText = searchBar.text {
            user = GithubAPI.user(searchText)
            user?.addObserver(self)
                 .addObserver(statusOverlay, owner: self)
                 .loadIfNeeded()
        }
    }
    
    func resourceChanged(resource: Resource, event: ResourceEvent) {
        userInfoView.hidden = (resource.latestData == nil)
        
        let json = resource.json
        usernameLabel.text = json["login"].string
        fullNameLabel.text = json["name"].string

        repoListVC?.repoList = resource
            .optionalRelative(json["repos_url"].string)?
            .withParam("type", "all")
            .withParam("sort", "updated")
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "repoList" {
            repoListVC = segue.destinationViewController as? RepositoryListViewController
        }
    }
    
    @IBAction func reload() {
        user?.load()
    }
}

