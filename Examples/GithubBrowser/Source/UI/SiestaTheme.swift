import UIKit
import Siesta
import SiestaUI

enum SiestaTheme {
    static let
        darkColor     = #colorLiteral(red: 0.180, green: 0.235, blue: 0.266, alpha: 1),
        darkerColor   = #colorLiteral(red: 0.161, green: 0.208, blue: 0.235, alpha: 1),
        lightColor    = #colorLiteral(red: 0.964, green: 0.721, blue: 0.329, alpha: 1),
        linkColor     = #colorLiteral(red: 0.321, green: 0.901, blue: 0.882, alpha: 1),
        selectedColor = #colorLiteral(red: 0.937, green: 0.400, blue: 0.227, alpha: 1),
        textColor     = #colorLiteral(red: 0.623, green: 0.647, blue: 0.663, alpha: 1),
        boldColor     = #colorLiteral(red: 0.906, green: 0.902, blue: 0.894, alpha: 1)

    static func applyAppearanceDefaults() {
        UITextField.appearance().keyboardAppearance = .dark
        UITextField.appearance().textColor = .black
        UITextField.appearance().backgroundColor = textColor

        UINavigationBar.appearance().barStyle = .black
        UINavigationBar.appearance().barTintColor = darkColor
        UINavigationBar.appearance().tintColor = linkColor

        UITableView.appearance().backgroundColor = darkerColor
        UITableView.appearance().separatorColor = .black
        UITableViewCell.appearance().backgroundColor = darkerColor
        UITableViewCell.appearance().selectedBackgroundView = emptyView(withBackground: selectedColor)

        UIButton.appearance().tintColor = linkColor

        UISearchBar.appearance().backgroundColor = darkColor
        UISearchBar.appearance().barTintColor = darkColor
        UISearchBar.appearance().searchBarStyle = .minimal
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).textColor = lightColor

        UILabel.appearance(whenContainedInInstancesOf: [ResourceStatusOverlay.self]).textColor = textColor
        UIActivityIndicatorView.appearance(whenContainedInInstancesOf: [ResourceStatusOverlay.self]).style = .large
    }

    static private func emptyView(withBackground color: UIColor) -> UIView {
        let view = UIView()
        view.backgroundColor = color
        return view
    }
}
