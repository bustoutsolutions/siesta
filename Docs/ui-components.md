# UI Components

## Resource Status Overlay

The business of showing an activity indicator and error message can get repetitive. Siesta provides a status overlay view that takes care of that for you.

The overlay is designed to cover your entire content view when there is an error, by you can position it as you like. It comes with a tidy standard layout:

<img alt="Standard error overlay view" src="/siesta/guide/images/standard-error-overlay@2x.png" width="320" height="136">

…and you can also provide your own custom nib.

Here’s a simple example of overlay usage:

```swift
class ProfileViewController: UIViewController, ResourceObserver {
    @IBOutlet weak var nameLabel, favoriteColorLabel: UILabel!
    
    let statusOverlay = ResourceStatusOverlay()

    override func viewDidLoad() {
        super.viewDidLoad()

        statusOverlay.embed(in: self)

        MyAPI.profile
            .addObserver(self)
            .addObserver(statusOverlay)
    }

    override func viewDidLayoutSubviews() {
        statusOverlay.positionToCoverParent()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        MyAPI.profile.loadIfNeeded()
    }

    func resourceChanged(_ resource: Resource, event: ResourceEvent) {
        let json = JSON(resource.jsonDict)
        nameLabel.text = json["name"].string
        favoriteColorLabel.text = json["favoriteColor"].string
    }
}
```

Or in Objective-C:

```objc
@interface ProfileViewController: UIViewController <BOSResourceObserver>
@property (weak,nonatomic) IBOutlet UILabel *nameLabel, *favoriteColorLabel;
@property (strong,nonatomic) ResourceStatusOverlay *statusOverlay;
@end

@implementation ProfileViewController

- (void) viewDidLoad {
    super.viewDidLoad()

    self.statusOverlay = [[[ResourceStatusOverlay alloc] init] embedIn:self];

    [[MyAPI.instance.profile
        addObserver:self]
        addObserver:statusOverlay];
}

- (void) viewDidLayoutSubviews {
    [_statusOverlay positionToCoverParent];
}

- (void) viewWillAppear: (BOOL) animated {
    [super viewWillAppear:animated];    
    [MyAPI.instance.profile loadIfNeeded];
}

- (void) resourceChanged: (BOSResource*) resource event: (NSString*) event {
    id json = resource.jsonDict;
    nameLabel.text = json[@"name"];
    favoriteColorLabel.text = json[@"favoriteColor"];
}

@end
```

## Remote Image View

TODO: document

See [API docs](https://bustoutsolutions.github.io/siesta/api/Classes/RemoteImageView.html)
