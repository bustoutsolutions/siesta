import Siesta
import SiestaUI
import UIKit

class index_md_0: UIViewController, ResourceObserver {
                                                            
    //══════ index_md:0 ══════
    let MyAPI = Service(baseURL: "https://api.example.com")
    //════════════════════════════════════
        
    //══════ index_md:1 ══════
    override func viewDidLoad() {
        super.viewDidLoad()
    
        MyAPI.resource("/profile").addObserver(self)
    }
    //════════════════════════════════════
        
    //══════ index_md:2 ══════
    func resourceChanged(_ resource: Resource, event: ResourceEvent) {
        nameLabel.text = resource.jsonDict["name"] as? String
        colorLabel.text = resource.jsonDict["favoriteColor"] as? String
    
        errorLabel.text = resource.latestError?.userMessage
    }
    //════════════════════════════════════
    
    var nameLabel: UILabel!
    var colorLabel: UILabel!
    var errorLabel: UILabel!
    var activityIndicator: UIActivityIndicatorView!

    func stuff() {                                                                                                                
        //══════ index_md:3 ══════
        MyAPI.resource("/profile").addObserver(owner: self) {
            [weak self] resource, _ in
        
            self?.nameLabel.text = resource.jsonDict["name"] as? String
            self?.colorLabel.text = resource.jsonDict["favoriteColor"] as? String
        
            self?.errorLabel.text = resource.latestError?.userMessage
        }
        //════════════════════════════════════
                
        //══════ index_md:4 ══════
        MyAPI.configureTransformer("/profile") {  // Path supports wildcards
            UserProfile(json: $0.content)         // Create models however you like
        }
        //════════════════════════════════════
                
        //══════ index_md:5 ══════
        // ... →
        MyAPI.resource("/profile").addObserver(owner: self) {
            [weak self] resource, _ in
            self?.showProfile(resource.typedContent())  // Response now contains UserProfile instead of JSON
        }
        
        func showProfile(profile: UserProfile?) {
            
        }
        //════════════════════════════════════
                
        //══════ index_md:7 ══════
        MyAPI.resource("/profile").addObserver(owner: self) {
            [weak self] resource, event in
        
            self?.activityIndicator.isHidden = !resource.isLoading
        }
        //════════════════════════════════════
        
    }

    func showProfile(_ profile: UserProfile?) { }
                                                            
    //══════ index_md:6 ══════
    override func viewWillAppear(_ animated: Bool) {
        MyAPI.resource("/profile").loadIfNeeded()
    }
    //════════════════════════════════════
        
    //══════ index_md:9 ══════
    class RemoteImageView: UIImageView {
      static var imageCache: Service = Service()
      
      var placeholderImage: UIImage?
      
      var imageURL: URL? {
        get { return imageResource?.url }
        set { imageResource = RemoteImageView.imageCache.resource(absoluteURL: newValue) }
      }
      
      var imageResource: Resource? {
        willSet {
          imageResource?.removeObservers(ownedBy: self)
          imageResource?.cancelLoadIfUnobserved(afterDelay: 0.05)
        }
        
        didSet {
          imageResource?.loadIfNeeded()
          imageResource?.addObserver(owner: self) { [weak self] _ in
            self?.image = self?.imageResource?.typedContent(
                ifNone: self?.placeholderImage)
          }
        }
      }
    }
    //════════════════════════════════════
    
}

enum index_md_1 {
    static let MyAPI = Service(baseURL: "https://api.example.com")                                    
    //══════ index_md:8 ══════
    class ProfileViewController: UIViewController, ResourceObserver {
        @IBOutlet weak var nameLabel, colorLabel: UILabel!
    
        @IBOutlet weak var statusOverlay: ResourceStatusOverlay!
    
        override func viewDidLoad() {
            super.viewDidLoad()
    
            MyAPI.resource("/profile")
                .addObserver(self)
                .addObserver(statusOverlay)
        }
        
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            MyAPI.resource("/profile").loadIfNeeded()
        }
    
        func resourceChanged(_ resource: Resource, event: ResourceEvent) {
            nameLabel.text  = resource.jsonDict["name"] as? String
            colorLabel.text = resource.jsonDict["favoriteColor"] as? String
        }
    }
    //════════════════════════════════════
    
}
