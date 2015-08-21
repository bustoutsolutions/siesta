---
title: 'UI Components'
layout: default
---

# UI Components

## ResourceStatusOverlay

The business of showing an activity indicator and error message can get repetitive. Siesta provides a status overlay view that takes care of that for you.

The overlay is designed to cover your entire content view when there is an error, by you can position it as you like. It comes with a tidy standard layout:

![Standard error overlay view](/siesta/guide/images/standard-error-overlay@2x.png){:width="320"}{:height="136"}
{:align="center"}

…and you can also provide your own custom nib.

Here’s a simple example of overlay usage:

```swift
class ProfileViewController: UIViewController, ResourceObserver {
    @IBOutlet weak var nameLabel, favoriteColorLabel: UILabel!
    
    let statusOverlay = ResourceStatusOverlay()

    override func viewDidLoad() {
        super.viewDidLoad()

        statusOverlay.embedIn(self)

        MyAPI.profile
            .addObserver(self)
            .addObserver(statusOverlay)
    }

    override func viewDidLayoutSubviews() {
        statusOverlay.positionToCoverParent()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        MyAPI.profile.loadIfNeeded()
    }

    func resourceChanged(resource: Resource, event: ResourceEvent) {
        let json = JSON(resource.json)
        nameLabel.text = json["name"].string
        favoriteColorLabel.text = json["favoriteColor"].string
    }
}
```

Or in Objective-C:

```objc
@interface ProfileViewController: UIViewController <BOSResourceObserver>
@property (weak,nonatomic) IBOutlet UILabel *nameLabel, *favoriteColorLabel;
@property (strong,nonatomic) BOSResourceStatusOverlay *statusOverlay;
@end

@implementation ProfileViewController

- (void) viewDidLoad {
    super.viewDidLoad()

    self.statusOverlay = [[[BOSResourceStatusOverlay alloc] init] embedIn:self];

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
    id json = resource.json;
    nameLabel.text = json[@"name"];
    favoriteColorLabel.text = json[@"favoriteColor"];
}

@end
```

Next: **[Memory Management](../memory)**
{: .guide-next}
