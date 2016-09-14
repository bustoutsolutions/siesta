import UIKit
import Siesta

enum SiestaTheme {
    static let
        darkColor     = UIColor(red: 0.180, green: 0.235, blue: 0.266, alpha: 1),
        darkerColor   = UIColor(red: 0.161, green: 0.208, blue: 0.235, alpha: 1),
        lightColor    = UIColor(red: 0.964, green: 0.721, blue: 0.329, alpha: 1),
        linkColor     = UIColor(red: 0.321, green: 0.901, blue: 0.882, alpha: 1),
        selectedColor = UIColor(red: 0.937, green: 0.400, blue: 0.227, alpha: 1),
        textColor     = UIColor(red: 0.623, green: 0.647, blue: 0.663, alpha: 1),
        boldColor     = UIColor(red: 0.906, green: 0.902, blue: 0.894, alpha: 1)

    static func applyAppearanceDefaults() {
        UITextField.appearance().keyboardAppearance = .dark
        UITextField.appearance().textColor = UIColor.black
        UITextField.appearance().backgroundColor = textColor

        UINavigationBar.appearance().barStyle = UIBarStyle.black
        UINavigationBar.appearance().barTintColor = darkColor
        UINavigationBar.appearance().tintColor = linkColor

        UITableView.appearance().backgroundColor = darkerColor
        UITableView.appearance().separatorColor = UIColor.black
        UITableViewCell.appearance().backgroundColor = darkerColor
        UITableViewCell.appearance().selectedBackgroundView = emptyView(withBackground: selectedColor)

        UIButton.appearance().backgroundColor = darkColor
        UIButton.appearance().tintColor = linkColor

        UISearchBar.appearance().backgroundColor = darkColor
        UISearchBar.appearance().barTintColor = darkColor
        UISearchBar.appearance().searchBarStyle = .minimal
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).textColor = lightColor

        UILabel.appearance(whenContainedInInstancesOf: [ResourceStatusOverlay.self]).textColor = textColor
        UIActivityIndicatorView.appearance(whenContainedInInstancesOf: [ResourceStatusOverlay.self]).activityIndicatorViewStyle = .whiteLarge
    }

    static private func emptyView(withBackground color: UIColor) -> UIView {
        let view = UIView()
        view.backgroundColor = color
        return view
    }
}
