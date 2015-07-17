//
//  ViewController.swift
//  GithubBrowser
//
//  Created by Paul on 2015/7/7.
//  Copyright © 2015 Bust Out Solutions. All rights reserved.
//

import UIKit
import Siesta
import SwiftyJSON

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
        user?.removeObservers(ownedBy: statusOverlay)
        user = nil
        
        if let searchText = searchBar.text {
            user = GithubAPI.instance.user(searchText)
            user?.addObserver(self)
            user?.addObserver(statusOverlay)
            user?.loadIfNeeded()
        }
    }
    
    func resourceChanged(resource: Resource, event: ResourceEvent) {
        userInfoView.hidden = (resource.latestData == nil)
        
        let json = JSON(resource.json)
        usernameLabel.text = json["login"].string
        fullNameLabel.text = json["name"].string
        
        repoListVC?.resource = resource.relative(json["repos_url"].string)
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

