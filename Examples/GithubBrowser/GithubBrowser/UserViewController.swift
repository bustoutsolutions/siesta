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
    }
    
    @IBAction func reload() {
        user?.load()
    }
}

