import UIKit
import Siesta

struct SiestaTheme {
    static let
        darkColor  = UIColor(red: 0.180, green: 0.235, blue: 0.266, alpha: 1),
        lightColor = UIColor(red: 0.964, green: 0.721, blue: 0.329, alpha: 1),
        linkColor  = UIColor(red: 0.321, green: 0.901, blue: 0.882, alpha: 1),
        textColor  = UIColor(red: 0.623, green: 0.647, blue: 0.663, alpha: 1),
        boldColor  = UIColor(red: 0.906, green: 0.902, blue: 0.894, alpha: 1)
    
    static func applyAppearanceDefaults() {
        UITextField.appearance().keyboardAppearance = .Dark
        UITextField.appearance().textColor = UIColor.blackColor()
        UITextField.appearance().backgroundColor = textColor
        
        UITableView.appearance().backgroundColor = darkColor
        UITableView.appearance().separatorColor = UIColor.blackColor()
        UITableViewCell.appearance().backgroundColor = darkColor

        UIButton.appearance().backgroundColor = darkColor
        UIButton.appearance().tintColor = linkColor
        
        UISearchBar.appearance().backgroundColor = darkColor
        UISearchBar.appearance().barTintColor = darkColor
        UISearchBar.appearance().searchBarStyle = .Minimal
        UITextField.appearanceWhenContainedInInstancesOfClasses([UISearchBar.self]).textColor = lightColor
        
        UILabel.appearanceWhenContainedInInstancesOfClasses([ResourceStatusOverlay.self]).textColor = textColor
        UIActivityIndicatorView.appearanceWhenContainedInInstancesOfClasses([ResourceStatusOverlay.self]).activityIndicatorViewStyle = .WhiteLarge
    }

    private init() { }
}
