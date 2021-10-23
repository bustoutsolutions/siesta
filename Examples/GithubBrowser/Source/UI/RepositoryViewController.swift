//
//  RepositoryViewController.swift
//  GithubBrowser
//
//  Created by Paul on 2016/7/16.
//  Copyright © 2016 Bust Out Solutions. All rights reserved.
//

import UIKit
import Siesta
import SiestaUI

class RepositoryViewController: UIViewController, ResourceObserver {

    // MARK: UI Elements

    @IBOutlet weak var starIcon: UILabel?
    @IBOutlet weak var starButton: UIButton?
    @IBOutlet weak var starCountLabel: UILabel?
    @IBOutlet weak var descriptionLabel: UILabel?
    @IBOutlet weak var homepageButton: UIButton?
    @IBOutlet weak var languagesLabel: UILabel?
    @IBOutlet weak var contributorsLabel: UILabel?

    var statusOverlay = ResourceStatusOverlay()

    // MARK: Resources

    var repositoryResource: Resource? {
        didSet {
            updateObservation(from: oldValue, to: repositoryResource)
        }
    }

    var starredResource: Resource? {
        didSet {
            updateObservation(from: oldValue, to: starredResource)
        }
    }

    var languagesResource: Resource? {
        didSet {
            updateObservation(from: oldValue, to: languagesResource)
        }
    }

    var contributorsResource: Resource? {
        didSet {
            updateObservation(from: oldValue, to: contributorsResource)
        }
    }

    private func updateObservation(from oldResource: Resource?, to newResource: Resource?) {
        guard oldResource != newResource else { return }

        oldResource?.removeObservers(ownedBy: self)
        newResource?
            .addObserver(self)
            .addObserver(statusOverlay, owner: self)
            .loadIfNeeded()
    }

    // MARK: Content conveniences

    var repository: Repository? {
        return repositoryResource?.typedContent()
    }

    var isStarred: Bool {
        return starredResource?.typedContent() ?? false
    }

    // MARK: Display

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = SiestaTheme.darkColor
        statusOverlay.embed(in: self)
        statusOverlay.displayPriority = [.anyData, .loading, .error]  // Prioritize partial data over loading indicator

        showRepository()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        CommentaryViewController.publishCommentary(
            """
            Go back and then go forward to this screen again. Note how everything reappears <i>instantly</i> for a
            previously viewed repository, even though the data spans multiple API requests. This behavior <b>emerges
            naturally</b> from Siesta’s approach.

            The app says “load if needed” for all the data on this screen every time you visit it, but this is not
            expensive. Why not? Siesta (1) has a <b>configurable notion of staleness</b> to prevent excessive network
            requests, and (2) it <b>transparently handles ETags</b> with no additional code or configuration.

            Siesta fights the dreaded Massive View Controller by <b>allowing separation of concerns</b> without
            requiring excessive layers of abstraction. For example, on this screen…

            …when you star/unstar the repository, the spin-while-requesting animation is <b>completely decoupled</b>
            from the logic that asks for an updated star count. Though tightly grouped in the UI, they live in entirely
            different sections of code. Study that code, and you’ll understand the power of Siesta.
            """)
    }

    func resourceChanged(_ resource: Resource, event: ResourceEvent) {
        showRepository()
    }

    func showRepository() {
        showBasicInfo()
        showStarred()
    }

    func showBasicInfo() {
        navigationItem.title = repository?.name
        descriptionLabel?.text = repository?.description
        homepageButton?.setTitle(repository?.homepage, for: .normal)

        if let contributors: [User] = contributorsResource?.typedContent() {
            contributorsLabel?.text = contributors
                .map { $0.login }
                .joined(separator: "\n")
        } else {
            contributorsLabel?.text = "–"
        }

        if let languages: [String:Int] = languagesResource?.typedContent() {
            languagesLabel?.text = languages.keys.joined(separator: " • ")
        } else {
            languagesLabel?.text = "–"
        }
    }

    func showStarred() {
        if let repository = repository {
            starredResource = GitHubAPI.currentUserStarred(repository)
        } else {
            starredResource = nil
        }

        contributorsResource = repositoryResource?.optionalRelative(
            repository?.contributorsURL)
        languagesResource = repositoryResource?.optionalRelative(
            repository?.languagesURL)

        starCountLabel?.text = repository?.starCount?.description
        starIcon?.text = isStarred ? "★" : "☆"
        starButton?.setTitle(isStarred ? "Unstar" : "Star", for: .normal)
        starButton?.isEnabled = (repository != nil)
    }

    // MARK: Actions

    @IBAction func toggleStar(_ sender: Any) {
        guard let repository = repository else { return }

        // Two things of note here:
        //
        // 1. Siesta guarantees onCompletion will be called exactly once, no matter what the error condition, so
        //    it’s safe to rely on it to stop the animation and reenable the button. No error recovery gymnastics!
        //
        // 2. Who changes the button title between “Star” and “Unstar?” Who updates the star count?
        //
        //    Answer: the setStarred(…) method itself updates both the starred resource and the repository resource,
        //    if the call succeeds. And why don’t we have to take any special action to deal with that here in
        //    toggleStar(…)? Because RepositoryViewController is already observing those resources, and will thus
        //    pick up the changes made by setStarred(…) without any futher intervention.
        //
        //    This is exactly what chainable callbacks are for: we add our onCompletion callback, somebody else adds
        //    their onSuccess callback, and neither knows about the other. Decoupling is lovely! And because Siesta
        //    parses responses only once, no matter how many callback there are, the performance cost is negligible.

        startStarRequestAnimation()
        GitHubAPI.setStarred(!isStarred, repository: repository)
            .onCompletion { _ in self.stopStarRequestAnimation() }
    }

    private func startStarRequestAnimation() {
        starButton?.isEnabled = false
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = 2 * Double.pi
        rotation.duration = 1.6
        rotation.repeatCount = Float.infinity
        starIcon?.layer.add(rotation, forKey: "loadingIndicator")
    }

    @objc private func stopStarRequestAnimation() {
        starButton?.isEnabled = true
        let stopRotation = CASpringAnimation(keyPath: "transform.rotation.z")
        stopRotation.toValue = -Double.pi * 2 / 5
        stopRotation.damping = 6
        stopRotation.duration = stopRotation.settlingDuration
        starIcon?.layer.add(stopRotation, forKey: "loadingIndicator")
    }

    @IBAction func openHomepage(_ sender: Any) {
        if let homepage = repository?.homepage,
           let homepageURL = URL(string: homepage) {
            UIApplication.shared.openURL(homepageURL)
        }
    }
}
